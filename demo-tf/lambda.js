exports.handler = async (event) => {
    const min = 1;
    const max = 6;    
    const randomNumber = Math.floor(
      Math.random() * (max - min + 1)
    ) + min;
    const message = 'Your dice throw resulted in: ' +
      randomNumber;
    return message;
  };