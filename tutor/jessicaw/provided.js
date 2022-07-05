(function fetchServerContent() {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'http://cs6035-warmup.gatech.edu:5000/forms/javascript-activity');
    xhr.onload = function () {
        document.getElementById("server-output").innerHTML = xhr.response;
        var ul = document.createElement("ul");
        ul.style = "list-style-type: none";
        document.getElementById("targetOutput").appendChild(ul);

        var imageHandler = function () {
            ul.appendChild(createChildli("GA Tech Image Loaded: Successful!"));
        };

        var studentValues = getStudentAnswers(imageHandler);

        ul.appendChild(createChildli("Username: " + studentValues.username));
        ul.appendChild(createChildli("Survived: " + studentValues.survived));

        if (studentValues.createdImg) {
            document.getElementById("img-here").appendChild(studentValues.createdImg);
        }


        var beforeValue = document.getElementById("submit-form-hidden").value;
        document.getElementById("submit-form-btn").click();
        var afterValue = document.getElementById("submit-form-hidden").value;

        if (beforeValue !== afterValue && afterValue === "999") {
            ul.appendChild(createChildli("Button Click Event: Successful!"));
        }

        function createChildli(value) {
            var li = document.createElement('li');
            li.innerText = value;
            return li;
        }
    };
    xhr.send();
})();
