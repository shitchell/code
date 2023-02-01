import numpy as np
from cgpt_ml_doc import LinearModel

# Generate synthetic data
np.random.seed(0)
X = np.random.rand(100, 1)
y = 2 + 3 * X + np.random.rand(100, 1)

# Instantiate LinearModel
model = LinearModel()

# Fit model to data
model.fit(X, y)

# Print model coefficients
print(f'Model coefficients: {model.model}')

# Predict on new data
X_new = np.random.rand(10, 1)
predictions = model.predict(X_new)
print(f'Predictions: {predictions}')

