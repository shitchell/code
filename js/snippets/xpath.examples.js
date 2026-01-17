// -------------------------------
// Example Usage:
// -------------------------------

// Using the generic evaluator:
let numberResult = evaluateXpath('count(//div)');
console.log('Number of <div> elements:', numberResult);

let nodesResult = evaluateXpath('//p');
console.log('Paragraph elements:', nodesResult);

// Using the extended methods on the document:
const firstDiv = document.getElementByXpath('//div');
console.log('First <div> element:', firstDiv);

const allParagraphs = document.getElementsByXpath('//p');
console.log('All <p> elements:', allParagraphs);

// And now you can call these methods on any element.
// For instance, if you have a container element:
const container = document.getElementById('container');
if (container) {
  const specificChild = container.getElementByXpath('.//span');
  console.log('A span inside #container:', specificChild);
}
