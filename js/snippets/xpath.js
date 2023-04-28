getXpathNumber = function(path) {
  return document.evaluate(path, document, null, XPathResult.numberValue, null).numberValue;
}
getElementByXpath = function(path) {
  return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
}
function getElementsByXpath(xpath, parent)
{
    let results = [];
    let query = document.evaluate(xpath, parent || document,
        null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
    for (let i = 0, length = query.snapshotLength; i < length; ++i) {
        results.push(query.snapshotItem(i));
    }
    return results;
}
