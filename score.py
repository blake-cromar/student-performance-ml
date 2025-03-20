import json
import joblib
import numpy as np
import pandas as pd
from azureml.core.model import Model

def init():
    global model
    model_path = Model.get_model_path("student_performance_model")  # Ensure model name matches deployment
    model = joblib.load(model_path)

def run(raw_data):
    try:
        # Convert input JSON data into a Pandas DataFrame
        data = json.loads(raw_data)
        df = pd.DataFrame(data)

        # Ensure the same feature selection as in training
        feature_columns = [
            "school", "sex", "age", "address", "famsize", "Pstatus", "Medu", "Fedu", 
            "Mjob", "Fjob", "reason", "guardian", "traveltime", "studytime", "failures",
            "schoolsup", "famsup", "paid", "activities", "nursery", "higher", "internet",
            "romantic", "famrel", "freetime", "goout", "Dalc", "Walc", "health", "absences",
            "G1", "G2"
        ]

        df = df[feature_columns]  # Keep only relevant features

        # Convert categorical variables
        df = pd.get_dummies(df)

        # Predict using the loaded model
        predictions = model.predict(df)

        # Return predictions as a list
        return json.dumps({"predictions": predictions.tolist()})
    
    except Exception as e:
        return json.dumps({"error": str(e)})