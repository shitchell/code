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
        # If the model has been instantiated without dimensions or a
        # pre-trained model, then use the dimensions of X to create a
        # new base model
        if self._model is None:
            self._model = np.empty((X.shape[1]+1, 1))
        # Update the existing model
        X = np.hstack([np.ones((X.shape[0], 1)), X])
        self._model = np.linalg.inv(X.T.dot(X)).dot(X.T).dot(y)

    def predict(self, X: np.ndarray):
        if self._model is None:
            raise ValueError("Model is not trained yet, call fit method to train the model before making predictions.")
        X = np.hstack([np.ones((X.shape[0], 1)), X])
        return X.dot(self._model)
