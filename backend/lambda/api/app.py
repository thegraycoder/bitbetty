import os
import uuid

import boto3
from boto3.dynamodb.conditions import Key, Attr
from chalice import Chalice, Response
from botocore.exceptions import ClientError
from decimal import Decimal


app = Chalice(app_name='api')


@app.route('/guesses', methods=['POST'], cors=True)
def add_guess():
    request = app.current_request
    body = request.json_body

    try:
        username = body['username']
        guess = body['guess']
        baseline_price = body['baseline_price']
        guessed_at = body['guessed_at']
    except KeyError as e:
        return Response(status_code=400, body={
           'message': f'Missing required field: {e}'
        })

    repo = Repository()
    if repo.has_unresolved_guesses(username):
        return Response(status_code=400, body={
            'message': 'User already has an unresolved guess'
        })
    guess_id = repo.add_guess(username, guess, baseline_price, guessed_at)

    try:
        queue = ResolutionQ()
        queue.add_to_queue(guess_id)
    except Exception as e:
        # If the item cannot be added to the queue, rollback the guess to allow re-try
        print(f"Failed to add to resolution queue. Error: {e}")
        repo.rollback(guess_id)
        return Response(status_code=500, body={
           'message': 'Could not add the guess for resolution'
        })

    return Response(status_code=201, body={
        'guess': guess_id,
        'message': 'Guess added successfully'
    })


@app.route('/scores/{username}', methods=['GET'], cors=True)
def get_score(username):
    print(f"Getting score for user: {username}")
    repo = Repository()
    score = repo.get_score(username)
    return Response(status_code=200, body={
        'score': score
    })


# TODO: Needs to be a different file, but chalice deployment doesn't support this yet
class Repository:

    def __init__(self):
        dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION'))
        table_name = os.environ.get('DYNAMODB_TABLE')
        self.table = dynamodb.Table(table_name)

    def add_guess(self, username: str, guess: float, baseline_price: str, guessed_at: str) -> str:
        guess_id = str(uuid.uuid4())
        try:
            self.table.put_item(
                Item={
                    'id': guess_id,
                    'username': username,
                    'guess': Decimal(guess),
                    'baseline_price': Decimal(baseline_price),
                    'guessed_at': guessed_at,
                    'resolved': False,
                    'points': Decimal(0)
                }
            )
            print(f"Guess {guess_id} added for user {username}.")
            return guess_id
        except ClientError as e:
            print(f"Error inserting guess: {e.response['Error']['Message']}")
            raise e

    def has_unresolved_guesses(self, username: str) -> bool:
        try:
            response = self.table.query(
                IndexName='username-index',
                KeyConditionExpression=Key('username').eq(username),
                FilterExpression=Attr('resolved').eq(False),
                Limit=1
            )
            return response['Count'] > 0

        except ClientError as e:
            print(f"Error checking for unresolved guesses: {e.response['Error']['Message']}")
            raise e

    def get_score(self, username: str) -> int:
        try:
            response = self.table.query(
                IndexName='username-index',
                KeyConditionExpression=Key('username').eq(username),
                FilterExpression=Attr('resolved').eq(True)
            )

            # Sum the points of all resolved guesses for the user
            total_score = sum(item['points'] for item in response['Items'])
            return int(total_score)

        except ClientError as e:
            print(f"Error getting score: {e.response['Error']['Message']}")
            raise e

    def rollback(self, guess_id):
        try:
            self.table.delete_item(
                Key={'id': guess_id}
            )
        except ClientError as e:
            print(f"Error rolling back guess: {e.response['Error']['Message']}")
            raise e


class ResolutionQ:
    def __init__(self):
        self.sqs = boto3.client('sqs', region_name=os.environ.get('AWS_REGION'))
        self.queue_url = os.environ.get('SQS_QUEUE_URL')

    def add_to_queue(self, guess_id: str):
        try:
            # We add a delay of 60 seconds to delay the resolution process
            self.sqs.send_message(QueueUrl=self.queue_url, MessageBody=guess_id, DelaySeconds=60)
            print(f"Guess {guess_id} added to resolution queue.")
        except ClientError as e:
            print(f"Error adding guess to resolution queue: {e.response['Error']['Message']}")
            raise e
