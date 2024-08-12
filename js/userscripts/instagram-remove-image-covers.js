// ==UserScript==
// @name         (Instagram) Remove Image Covers
// @description  Remove the HTML image covers from Instagram posts
// @namespace    Violentmonkey Scripts
// @match        https://www.instagram.com/*
// @grant        none
// @version      0.1
// @author       Shaun Mitchell <shaun@shitchell.com>
// @run-at       document-end
// @license      WTFPL
// ==/UserScript==

/* How it works:

Images on Instagram are covered with an empty div, preventing you from
right-clicking and saving the image. This script removes that div. In the HTML,
this looks like:

```html
<div>
    <div style="padding-bottom: 99.9306%;" class="_aagv">
        <img
            alt="Photo by John Smith on August 11, 2024."
            crossorigin="anonymous"
            class="x5yr21d xu96u03 x10l6tqk x13vifvy x87ps6o xh8yej3"
            style="object-fit: cover;"
            src="https://scontent-foo.cdninstagram.com/.../image.jpg">
    </div>
    <div class="_aagw"></div>
<div>
```

Where the `<div class="_aagw"></div>` is the cover. This script will find all
images, jump up a level, find the cover div, perform a couple validations to
ensure it's the correct div, and then remove it.

*/

/**
 * Search for and remove covers from a list of nodes or the entire document
 *
 * @param {NodeListOf<Element>} nodes A list of nodes to search for images
 */
function removeImageCovers(nodes) {
    let images = [];
    if (!nodes) nodes = [document];

    // Find all images in each node
    for (let i = 0; i < nodes.length; i++) {
        images.push(...nodes[i].querySelectorAll('img'));
    }

    // Remove the cover from each image
    images.forEach((image) => {
        const parent = image.parentElement;
        const grandParent = parent.parentElement;
        const cover = parent.nextElementSibling;

        /** Validate we found the cover ***************************************/
        // We can't validate by class name because it's dynamically generated to
        // prevent... well, this. So instead, we'll check that:
        //   1. There is a grandParent and parent
        //   2. the grandParent element has only two children (parent and cover)
        //   3. the cover element has no children
        //
        // If this proves to not be enough, we might also check that the image
        // has the "object-fit: cover;" style applied. That is left out for now
        // because that feels more prone to change or like it might not be used
        // in all cases depending on the image size.

        // 1. Grandparent and parent are present
        if (!grandParent) return;
        if (!parent) return;

        // 2a. Grandparent has 2 children
        if (grandParent.children.length !== 2) return;

        // 2b. Grandparent's children are the parent and cover
        if (grandParent.children[0] !== parent) return;
        if (grandParent.children[1] !== cover) return;

        // 3. Cover has no children
        if (cover.children.length !== 0) return;

        /** Remove the cover **************************************************/
        grandParent.removeChild(cover);
    });
}

(function() {
    'use strict';

    // Remove covers from the entire document on load
    removeImageCovers();

    // Remove covers from new posts as they're loaded
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            removeImageCovers(mutation.addedNodes);
        });
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();
