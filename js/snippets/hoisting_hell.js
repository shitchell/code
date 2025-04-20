// Works
console.log("Setting `a` to `1` and then logging inside braces (works)");
let a = 1;
{
    console.log(`a => ${a}`);
}

// Doesn't work
console.log("Setting `b` to `1`, logging its value, then setting it to `2` (fails)")
let b = 1;
{
    console.log(b); // ReferenceError
    let b = 2;
}
