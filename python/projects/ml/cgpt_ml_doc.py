import numpy as np

class LinearModel:
    def __init__(self, cols: int = None, rows: int = None, model: np.ndarray = None):
        if (cols is not None and rows is not None) and model is None:
            self._model = np.empty((rows, cols))
        else:
            self._model = model
        
    @property
    def cols(self):
        if self._model is None:
            return None
        return self._model.shape[1]
    
    @property
    def rows(self):
        if self._model is None:
            return None
        return self._model.shape[0]
    
    @property
    def model(self):
        return self._model

    def fit(self, X: np.ndarray, y: np.ndarray):
        if self._model is None:
            # Get the columns of X
            x_cols = X.shape[1]
            # Set the new model's rows to x_cols + 1
            model_rows = x_cols + 1
            # Set self._model to an empty numpy array with model_rows rows and 1 column
            self._model = np.empty((model_rows, 1))

        # Add a bias term to X
        bias_term = np.ones((X.shape[0], 1)) 
        X = np.hstack([bias_term, X])
        
        # Compute the transpose of X
        X_transpose = X.T
        # Multiply X transpose with X
        X_transpose_X = X_transpose.dot(X)
        # Compute the inverse of X_transpose_X
        X_transpose_X_inv = np.linalg.inv(X_transpose_X)
        # Multiply X_transpose_X_inv with X_transpose
        X_transpose_X_inv_X_transpose = X_transpose_X_inv.dot(X_transpose)
        # Multiply X_transpose_X_inv_X_transpose with y
        self._model = X_transpose_X_inv_X_transpose.dot(y)

    def predict(self, X: np.ndarray):
        if self._model is None:
            raise ValueError("Model is not trained yet, call fit method to train the model before making predictions.")
        
        # Add a bias term to X
        bias_term = np.ones((X.shape[0], 1)) 
        X = np.hstack([bias_term, X])
        # Multiply X with the model
        predictions = X.dot(self._model)
        return predictions
