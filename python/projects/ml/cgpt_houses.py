import numpy as np
from cgpt_ml_doc import LinearModel

# Create a dataset of house sq footage and bedrooms
x_train = np.array([
 [2104, 3],
 [1600, 2],
 [2400, 1],
 [5730, 4]
])

# Create a correlating dataset of house prices
y_train = np.array([400_000, 330_000, 369_000, 700_000])

# Create a test dataset of house sq footage and bedrooms
x_test = np.array([
 [2040, 3],
 [1230, 1],
 [1231, 2],
 [8000, 3],
 [1000, 5]
])

# Create a model from the data
model = LinearModel()
model.fit(x_train, y_train)

print("Trained model using house footage, bedrooms, and prices:")
print(f"{x_train=}\n{y_train=}")
print()
print("Test footage and bedrooms:")
print(f"{x_test}")
print()
print("Predictions based on test data:")
print(model.predict(x_test))
