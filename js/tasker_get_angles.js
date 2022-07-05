window.addEventListener("deviceorientation", getAngles, true);

function getAngles(e) {
	setGlobal("LOG", "getting angles...");
	console.log("getting angles...");
	let xAngle = e.beta;
	let yAngle = e.gamma;
	let zAngle = e.alpha;
	console.log(`deviceorientation: x: ${xAngle}, y: ${yAngle}, z: ${zAngle}`);
	performTask("kustom-broadcast", 10, xAngle, "xAngle");
	performTask("kustom-broadcast", 10, yAngle, "yAngle");
	performTask("kustom-broadcast", 10, zAngle, "zAngle");
	setGlobal("ANGLE_X", xAngle);
	setGlobal("ANGLE_Y", yAngle);
	setGlobal("ANGLE_Z", zAngle);
	setGlobal("LOG", `x: ${xAngle}, y: ${yAngle}, z: ${zAngle}`);
	exit();
}
