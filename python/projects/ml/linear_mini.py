import numpy as np

class LinearRegression:
  def __init__(self):
    self.w = None

  def fit(self, X, y):
    X = np.hstack([np.ones((X.shape[0], 1)), X])
    self.w = np.linalg.solve(X.T @ X, X.T @ y)

  def predict(self, X):
    X = np.hstack([np.ones((X.shape[0], 1)), X])
    return X @ self.w
