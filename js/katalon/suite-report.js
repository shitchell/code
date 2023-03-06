var LEVELS = {PASSED: 0, FAILED: 1, INFO: 2, ERROR: 3};
function toggleSuite(suiteId) {
    toggleElement(suiteId, ['keyword', 'suite', 'test']);
}
function toggleTest(testId) {
    toggleElement(testId, ['keyword']);
}
function toggleKeyword(kwId) {
    toggleElement(kwId, ['keyword', 'message']);
}
function toggleDataBinding(dbId) {
	var element = $('#' + dbId);
    var children = element.children('.children');
    children.toggle(100, '', function () {
        element.children('.element-header').toggleClass('closed');
    });
}
function toggleElement(elementId, childrenNames) {
    var element = $('#' + elementId);
    var children = element.children('.children');
    children.toggle(100, '', function () {
        element.children('.element-header').toggleClass('closed');
    });
    populateChildren(elementId, children, childrenNames);
}
function populateChildren(elementId, childElement, childrenNames) {
    if (!childElement.hasClass('populated')) {
        var element = window.testdata.findLoaded(elementId);
        var callback = drawCallback(element, childElement, childrenNames);
        element.callWhenChildrenReady(callback);
        childElement.addClass('populated');
    }
}
function drawCallback(element, childElement, childrenNames) {
    return function () {
        util.map(childrenNames, function (childName) {
            var children = element[childName + 's']();
            var template = childName + 'Template';
            util.map(children, function (child) {
                $.tmpl(template, child).appendTo(childElement);
            });
        });
    }
}
function expandRecursively() {
    if (!window.elementsToExpand.length)
        return;
    var element = window.elementsToExpand.pop();
    if (!element || elementHiddenByUser(element.id)) {
        window.elementsToExpand = [];
        return;
    }
    expandElement(element);
    element.callWhenChildrenReady(function () {
        var children = element.children();
        for (var i = children.length-1; i >= 0; i--) {
            if (window.expandDecider(children[i]))
                window.elementsToExpand.push(children[i]);
        }
        if (window.elementsToExpand.length)
            setTimeout(expandRecursively, 0);
    });
}
function expandElement(item) {
    var element = $('#' + item.id);
    var children = element.children('.children');
    // .css is faster than .show and .show w/ callback is terribly slow
    children.css({'display': 'block'});
    populateChildren(item.id, children, item.childrenNames);
    element.children('.element-header').removeClass('closed');
    if (item.dataBindings != null && !item.dataBindings.isEmpty) {
	    var dataBindingElement = $('#' + item.dataBindings.id);
	    if (dataBindingElement.children('.element-header').hasClass('closed')) {
	        toggleDataBinding(item.dataBindings.id);
	    }
    }
}
function expandElementWithId(elementid) {
    expandElement(window.testdata.findLoaded(elementid));
}
function elementHiddenByUser(elementId) {
    var element = $("#"+elementId);
    return !element.is(":visible");
}
function expandAllChildren(elementId) {
    window.elementsToExpand = [window.testdata.findLoaded(elementId)];
    window.expandDecider = function () { return true; };
    expandRecursively();
}
function expandCriticalFailed(element) {
    if (element.status == "FAIL") {
        window.elementsToExpand = [element];
        window.expandDecider = function (e) {
            return e.status == "FAIL" && (e.isCritical === undefined || e.isCritical);
        };
        expandRecursively();
    }
}
function expandSuite(suite) {
    if (suite.status == "PASSED")
        expandElement(suite);
    else
        expandCriticalFailed(suite);
}
function logLevelSelected(level) {
    var anchors = getViewAnchorElements();
    setMessageVisibility(level);
    scrollToShortestVisibleAnchorElement(anchors);
}
function getViewAnchorElements() {
    var elem1 = $(document.elementFromPoint(100, 0));
    var elem2 = $(document.elementFromPoint(100, 20));
    return [elem1, elem2];
}
function scrollToShortestVisibleAnchorElement(anchors) {
    anchors = util.map(anchors, closestVisibleParent);
    var shortest = anchors[0];
    for (var i = 1; i < anchors.length; i++)
        if (shortest.height() > anchors[i].height())
            shortest = anchors[i];
    shortest.get()[0].scrollIntoView(true);
}
function setMessageVisibility(level) {
    level = parseInt(level);
}
function closestVisibleParent(elem) {
    while (!elem.is(":visible"))
        elem = elem.parent();
    return elem;
}
function changeClassDisplay(clazz, visible) {
    var styles = document.styleSheets;
    for (var i = 0; i < styles.length; i++) {
        var rules = getRules(styles[i]);
        if (rules === null)
            continue;
        for (var j = 0; j < rules.length; j++)
            if (rules[j].selectorText === clazz)
                rules[j].style.display = visible ? "table" : "none";
    }
}
function getRules(style) {
    // With Chrome external CSS files seem to have only null roles and with
    // Firefox accessing rules can result to security error.
    // Neither of these are a problem on with generated logs.
    try {
        return style.cssRules || style.rules;
    } catch (e) {
        return null;
    }
}
function selectMessage(parentId) {
    var element = $('#' + parentId).find('.message').get(0);
    selectText(element);
}
function selectText(element) {
    // Based on http://stackoverflow.com/questions/985272
    var range, selection;
    if (document.body.createTextRange) {  // IE 8
        range = document.body.createTextRange();
        range.moveToElementText(element);
        range.select();
    } else if (window.getSelection) {  // Others
        selection = window.getSelection();
        range = document.createRange();
        range.selectNodeContents(element);
        selection.removeAllRanges();
        selection.addRange(range);
    }
}
function LogLevelController(minLevel, defaultLevel) {
    minLevel = 0;
    defaultLevel = 2;
    function showLogLevelSelector() {
        return false;
    }
    function defaultLogLevel() {
        if (minLevel > defaultLevel)
            return minLevel;
        return defaultLevel;
    }
    function showTrace() {
        return false;
    }
    return {
        showLogLevelSelector: showLogLevelSelector,
        defaultLogLevel: defaultLogLevel,
        showTrace: showTrace
    };
}

//// Main ////

$(document).ready(function() {
    try {
        var topsuite = window.testdata.suite();
    } catch (error) {
        addJavaScriptDisabledWarning(error);
        return;
    }
    initLayout(topsuite.name, 'Log');
    //addStatistics();
    addErrors();
    addExecutionEnvironmentInfo(window.environment_info);
    addTestExecutionLog(topsuite);
    addLogLevelSelector(window.settings['minLevel'], window.settings['defaultLevel']);
    if (window.location.hash) {
        makeElementVisible(window.location.hash.substring(1));
    } else {
        expandSuite(topsuite);
    }
    
    if($("s1").attr('class') == 'element-header closed'){
		toggleSuite('s1')
	}
	$("#s1").find("div[id*='s1-t']").each(function(){
		if (!this.id.includes('dataBinding')) {
      		toggleTest(this.id);
    	}
	});
    
});

function addLogLevelSelector(minLevel, defaultLevel) {
    var controller = LogLevelController(minLevel, defaultLevel);
    if (controller.showLogLevelSelector()) {
        var selector = $.tmpl('logLevelSelectorTemplate', controller);
        selector.find('select').val(controller.defaultLogLevel());
        selector.appendTo($('#top-right-header'));
        $('#report-or-log-link').find('a').css({'border-bottom-left-radius': '0'});
        setMessageVisibility(controller.defaultLogLevel());
    }
}

function addErrors() {
    var errors = window.testdata.errorIterator();
    if (errors.hasNext()) {
        $.tmpl('errorHeaderTemplate').appendTo($('body'));
        drawErrorsRecursively(errors, $('#errors'));
    }
}

function drawErrorsRecursively(errors, target) {
    var elements = popFromIterator(errors, 10);
    $.tmpl('errorTemplate', elements).appendTo(target);
    if (errors.hasNext())
        setTimeout(function () { drawErrorsRecursively(errors, target); }, 0);
    else
        scrollToHash();
}

function scrollToHash() {
    if (window.location.hash)
        setTimeout(function () {
            var id = window.location.hash.substring(1);
            window.location.hash = '#';
            window.location.hash = id;
            highlight($('#' + id));
        }, 0);
}

function highlight(element, color) {
    if (color === undefined)
        color = 242;
    if (color < 255) {
        element.css({'background-color': 'rgb('+color+','+color+','+color+')'});
        setTimeout(function () { highlight(element, color+1); }, 300);
    } else {
        element.css({'background-color': ''});
    }
}

function popFromIterator(iterator, upTo) {
    var result = [];
    while (iterator.hasNext() > 0 && result.length < upTo)
        result.push(iterator.next());
    return result;
}

function makeElementVisible(id) {
    window.testdata.ensureLoaded(id, function (ids) {
        util.map(ids, expandElementWithId);
        if (ids.length) {
            expandCriticalFailed(window.testdata.findLoaded(util.last(ids)));
            window.location.hash = id;
            scrollToHash();
        }
    });
}

function addTestExecutionLog(main) {
    $('body').append($('<h2>Test Execution Log</h2>'),
                     $.tmpl('suiteTemplate', main));
}

function addExecutionEnvironmentInfo(environment_info) {
    $('body').append($('<h2>Execution Environment</h2>'),
                     $.tmpl('testEnvironmentInfoTemplate', environment_info));
}

//// Custom ////

function expandFailed(e) {
    if (e.status === 'FAILED') {
        expandElement(e);
        console.log("expanded", e);
        // If window.elementsToExpand is undefined, set it to an empty array
        window.elementsToExpand = window.elementsToExpand || [];
        console.log("setting up children callback");
        e.callWhenChildrenReady(function () {
            // If the element has a `children` function, loop over the children
            // and expand all with a status of "FAILED"
            console.log(`checking if element ${e.name} has children`);
            if (e.children === undefined) {
                return;
            }
            console.log(`element ${e.name} has children, looping`);
            var children = e.children();
            console.log(`${e.name} has ${children.length} children`, children);
            for (var i = children.length - 1; i > 0; i--) {
                console.log("expanding child", children[i]);
                expandFailed(children[i]);
            }
        });
    } else {
        console.log(`element ${e.name} has status ${e.status}, not expanding`);
    }
}

function expandAllFailed() {
    // Loop over the children array and expand all with a status of "FAILED"
    var children = window.testdata.suite().children();
    for (var i = 0; i < children.length; i++) {
        expandFailed(children[i]);
    }
}
