import json
import joblib
import numpy as np
import pandas as pd
import os
from azureml.core.model import Model

def init():
    global model
    model_path = Model.get_model_path("student-performance-model")  # Ensure exact name match
    model = joblib.load(model_path)

def run(raw_data):
    try:
        # Parse input JSON data into a Pandas DataFrame
        data = json.loads(raw_data)
        df = pd.DataFrame(data)

        # Ensure the same feature order as training (if required)
        feature_columns = [
            "school", "sex", "age", "address", "famsize", "Pstatus", "Medu", "Fedu", 
            "Mjob", "Fjob", "reason", "guardian", "traveltime", "studytime", "failures",
            "schoolsup", "famsup", "paid", "activities", "nursery", "higher", "internet",
            "romantic", "famrel", "freetime", "goout", "Dalc", "Walc", "health", "absences",
            "G1", "G2"
        ]
        df = df[feature_columns]

        # Predict directly using the AutoML model pipeline (no manual encoding needed)
        predictions = model.predict(df)

        # Return predictions in JSON format
        return json.dumps({"predictions": predictions.tolist()})

    except Exception as e:
        return json.dumps({"error": str(e)})
