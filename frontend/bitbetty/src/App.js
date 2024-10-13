import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend } from 'chart.js';
import GuessForm from './components/GuessForm';
import './App.css';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend);

const App = () => {
  const [score, setScore] = useState(0);
  const [btcPrice, setBtcPrice] = useState(null);
  const [isGuessResolved, setIsGuessResolved] = useState(true);
  const [timeRemaining, setTimeRemaining] = useState(60);
  const [username, setUsername] = useState('');
  const [usernameSubmitted, setUsernameSubmitted] = useState(false);
  const [priceData, setPriceData] = useState([]);
  const [timeData, setTimeData] = useState([]);
  const BASE_URL = 'https://kk3yl6au72.execute-api.eu-central-1.amazonaws.com/prod';


  useEffect(() => {
    if (usernameSubmitted) {
      fetchScore();
    }
  }, [usernameSubmitted]);

  // Fetch BTC price every few seconds
  useEffect(() => {
    const fetchBTCPrice = async () => {
      try {
        const response = await axios.get('https://api.coindesk.com/v1/bpi/currentprice/USD.json');
        const currentPrice = response.data.bpi.USD.rate_float;
        const currentTime = new Date().toLocaleTimeString();

        // Update price and time data for graph
        setPriceData((prevData) => [...prevData, currentPrice]);
        setTimeData((prevTime) => [...prevTime, currentTime]);

        setBtcPrice(currentPrice);
      } catch (error) {
        console.error('Error fetching BTC price:', error);
      }
    };

    fetchBTCPrice();
    const interval = setInterval(fetchBTCPrice, 5000); // Update price every 5 seconds
    return () => clearInterval(interval); // Cleanup interval on component unmount
  }, []);

  // Handle guess submission
  const handleGuess = (userGuess) => {
    if (!isGuessResolved) return; // Prevent multiple guesses before resolution
    const postGuess = async () => {
        try {
            const response = await axios.post(BASE_URL + '/guesses', {
              username: username,
              guess: userGuess,
              baseline_price: btcPrice.toString(),
              guessed_at: new Date().toISOString(),
            });
            console.log('Guess submitted:', response.status);
            setIsGuessResolved(false);
            setTimeRemaining(60); // Reset timer
        } catch (error) {
            console.error('Error resolving guess:', error);
        }
    }
    postGuess();
  };

  // Countdown timer
  useEffect(() => {
    if (timeRemaining <= 0 && !isGuessResolved) {
      resolveGuess();
    }
    if (timeRemaining > 0 && !isGuessResolved) {
      const timer = setInterval(() => {
        setTimeRemaining((prev) => prev - 1);
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [timeRemaining, isGuessResolved]);

  // Fetch and update the score
  const fetchScore = async () => {
    try {
      const response = await axios.get(BASE_URL + '/scores/' + username);
      if (response.data.score === score) {
        console.log('score has not updated yet');
        return false;
      }
      setScore(response.data.score);
      return true;
    } catch (error) {
      console.error('Error fetching score:', error);
      return false; // Score has not updated yet
    }

  }
  // Resolve the guess and update score
  const resolveGuess = () => {
    console.log('Resolve guess');
    try {
      const fetched = fetchScore();
      if (!fetched) return; // Score has not updated yet
      console.log('Resolving guess...');
      setIsGuessResolved(true);
    } catch (error) {
      console.error('Error resolving guess:', error);
    }
  };

  // Line chart data configuration
  const data = {
    labels: timeData,
    datasets: [
      {
        label: 'BTC Price',
        data: priceData,
        borderColor: '#f0a500',
        backgroundColor: '#f0a500',
        pointRadius: 2,
        pointHoverRadius: 7,
        pointBackgroundColor: '#fff',
        pointBorderWidth: 2,
      },
    ],
  };

  // Line chart options
  const options = {
    responsive: true,
    maintainAspectRatio: false,
    animation: {
      duration: 500,
      easing: 'easeInOutQuad',
    },
    scales: {
      x: {
        title: {
          display: true,
//          text: 'Time',
        },
      },
      y: {
        title: {
          display: true,
//          text: 'Price (USD)',
        },
      },
    },
  };

  return (
    <div className="App">
      <h1>BitBetty</h1>
      <h4>Bitcoin price guessing game</h4>
      {!usernameSubmitted ? (
        <div>
          <input
            type="text"
            placeholder="Enter your username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            data-testid="username-input"
          />
          <button onClick={() => setUsernameSubmitted(true)} data-testid="username-submit-button">
            Submit Username
          </button>
        </div>
      ) : (
        <div className="game-container">
          <h3>Current price: ${btcPrice}</h3>
          <div className="chart-container">
            <Line data={data} options={options} />
          </div>
          <div className="controls-container">
            <h3 data-testid="score">Score: {score}</h3>
            <GuessForm handleGuess={handleGuess} isGuessResolved={isGuessResolved} />
            {!isGuessResolved && (
              <p data-testid="timer">Time remaining: {timeRemaining} seconds</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default App;
