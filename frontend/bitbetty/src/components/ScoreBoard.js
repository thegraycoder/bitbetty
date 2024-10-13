import React from 'react';

const ScoreBoard = ({ score, btcPrice }) => {
  return (
    <div>
      <h2 data-testid="score">Score: {score}</h2>
      <h3 data-testid="btc-price">Current BTC Price: ${btcPrice ? btcPrice.toFixed(2) : 'Loading...'}</h3>
    </div>
  );
};

export default ScoreBoard;
