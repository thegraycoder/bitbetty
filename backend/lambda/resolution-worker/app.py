import os
from datetime import datetime, timezone
from dateutil import parser

import boto3
import requests
from chalice import Chalice
from botocore.exceptions import ClientError

app = Chalice(app_name='resolution-worker')

QUEUE_NAME = 'guesses'


@app.lambda_function()
def handle_guesses(event, context):
    for record in event['Records']:
        guesses_id = record['body']
        print(f'Received message: {guesses_id}')
        guess = Guess(guesses_id)
        timeleft = guess.timeleft_for_resolution()
        price = get_current_btc_price()
        if timeleft <= 0 and guess.has_price_changed(price):
            guess.resolve(price)
        else:
            queue = boto3.resource('sqs')
            queue.change_message_visibility(
                ReceiptHandle=record['ReceiptHandle'],
                VisibilityTimeout=timeleft if timeleft > 0 else 5,
            )


# TODO: Needs to be a different file, but chalice deployment doesn't support this yet
class Guess:

    def __init__(self, guess_id):
        dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION'))
        table_name = os.environ.get('DYNAMODB_TABLE')
        self.table = dynamodb.Table(table_name)
        try:
            response = self.table.get_item(
                Key={'id': guess_id}
            )
            print(f"database item: {response}")
            self.guess = response['Item']
        except ClientError as e:
            print(f"Error getting guess: {e}")
            raise e

    def get(self) -> dict:
        return self.guess

    def timeleft_for_resolution(self) -> float:
        guessed_at = self.guess['guessed_at']
        guessed_at_dt = parser.parse(guessed_at)
        current_time = datetime.now(timezone.utc)
        return 60 - (current_time - guessed_at_dt).total_seconds()

    def has_price_changed(self, price) -> bool:
        return self.guess['baseline_price'] != price

    def resolve(self, price) -> None:
        if self.guess['resolved']:
            return
        prediction = self.guess['guess']
        baseline_price = self.guess['baseline_price']
        if (prediction == 1 and price > baseline_price) or (prediction == -1 and price < baseline_price):
            self.table.update_item(
                Key={'id': self.guess['id']},
                UpdateExpression='SET resolved = :true, points = :points',
                ExpressionAttributeValues={
                    ':true': True,
                    ':points': 1
                }
            )
            print(f"Guess {self.guess['id']} resolved with a price of ${price}. The guess was correct.")
        else:
            self.table.update_item(
                Key={'id': self.guess['id']},
                UpdateExpression='SET resolved = :true, points = :points',
                ExpressionAttributeValues={
                    ':true': True,
                    ':points': -1
                }
            )
            print(f"Guess {self.guess['id']} resolved with a price of ${price}. The guess was incorrect.")
        return


def get_current_btc_price() -> float:
    url = 'https://api.coindesk.com/v1/bpi/currentprice/BTC.json'
    try:
        # Send a GET request to the CoinDesk API
        response = requests.get(url)
        # Check if the request was successful (status code 200)
        if response.status_code == 200:
            # Parse the JSON response
            data = response.json()
            # Extract the BTC price in USD
            btc_price_usd = data['bpi']['USD']['rate_float']
            print(f"Current BTC price in USD: ${btc_price_usd}")
            return btc_price_usd
        else:
            print(f"Failed to retrieve BTC price. Status code: {response.status_code}")
            return -1
    except Exception as e:
        print(f"Error occurred while fetching BTC price: {e}")
        return -1
