import React from 'react';

const GuessForm = ({ handleGuess, isGuessResolved }) => {
  return (
    <div>
      <h3>Make a guess: </h3>
      <button onClick={() => handleGuess('1')} disabled={!isGuessResolved} data-testid="up-button">Up</button>
      <button onClick={() => handleGuess('-1')} disabled={!isGuessResolved} data-testid="down-button">Down</button>
    </div>
  );
};

export default GuessForm;
