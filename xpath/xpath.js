function getElementByXpath(path) {
  return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
}

function getXpathNumber(path) {
  return document.evaluate(path, document, null, XPathResult.NUMBER_TYPE, null).numberValue;
}

