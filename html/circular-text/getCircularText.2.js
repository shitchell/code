function getCircularText(text, diameter, startAngle, align, textInside, inwardFacing, fName, fSize, kerning, textColor, bgColor, bgOpacity) {
    // text:         The text to be displayed in circular fashion
    // diameter:     The diameter of the circle around which the text will
    //               be displayed (inside or outside)
    // startAngle:   In degrees, Where the text will be shown. 0 degrees
    //               if the top of the circle
    // align:        Positions text to left right or center of startAngle
    // textInside:   true to show inside the diameter. False to show outside
    // inwardFacing: true for base of text facing inward. false for outward
    // fName:        name of font family. Make sure it is loaded
    // fSize:        size of font family. Don't forget to include units
    // kerning:      0 for normal gap between letters. positive or
    //               negative number to expand/compact gap in pixels
    // textColor:    The color of the text
    // bgColor:      The color of the background
    // bgOpacity:    The opacity of the background
    //--------------------------------------------------------------------------
    
    // declare and intialize canvas, reference, and useful variables
    align = align.toLowerCase();
    var mainCanvas = document.createElement('canvas');
    var ctxRef = mainCanvas.getContext('2d');
    var clockwise = align == "right" ? 1 : -1; // draw clockwise for aligned right. Else Anticlockwise
    startAngle = startAngle * (Math.PI / 180); // convert to radians

    // calculate height of the font. Many ways to do this
    var div = document.createElement("div");
    div.innerHTML = text;
    div.style.position = 'absolute';
    div.style.top = '-10000px';
    div.style.left = '-10000px';
    div.style.fontFamily = fName;
    div.style.fontSize = fSize;
    document.body.appendChild(div);
    var textHeight = div.offsetHeight;
    document.body.removeChild(div);

    // in cases where we are drawing outside diameter,
    if (!textInside) diameter += textHeight * 2;

    mainCanvas.width = diameter;
    mainCanvas.height = diameter;
    ctxRef.font = fSize + ' ' + fName;

    // Set background color with opacity
    ctxRef.fillStyle = `rgba(${hexToRgb(bgColor)}, ${bgOpacity})`;
    ctxRef.fillRect(0, 0, mainCanvas.width, mainCanvas.height);
    ctxRef.fillStyle = textColor;

    // Reverse letters for align Left inward, align right outward 
    if (((["left", "center"].indexOf(align) > -1) && inwardFacing) || (align == "right" && !inwardFacing)) text = text.split("").reverse().join(""); 

    // Setup letters and positioning
    ctxRef.translate(diameter / 2, diameter / 2); // Move to center
    startAngle += (Math.PI * !inwardFacing); // Rotate 180 if outward
    ctxRef.textBaseline = 'middle'; // Ensure we draw in exact center
    ctxRef.textAlign = 'center'; // Ensure we draw in exact center

    // rotate 50% of total angle for center alignment
    if (align == "center") {
        for (var j = 0; j < text.length; j++) {
            var charWid = ctxRef.measureText(text[j]).width;
            startAngle += ((charWid + (j == text.length-1 ? 0 : kerning)) / (diameter / 2 - textHeight)) / 2 * -clockwise;
        }
    }

    // Rotate into final start position
    ctxRef.rotate(startAngle);

    // Draw and rotate characters
    for (var j = 0; j < text.length; j++) {
        var charWid = ctxRef.measureText(text[j]).width; // half letter
        ctxRef.rotate((charWid / 2) / (diameter / 2 - textHeight) * clockwise); 
        ctxRef.fillText(text[j], 0, (inwardFacing ? 1 : -1) * (0 - diameter / 2 + textHeight / 2));
        ctxRef.rotate((charWid / 2 + kerning) / (diameter / 2 - textHeight) * clockwise); 
    }

    return mainCanvas;
}
