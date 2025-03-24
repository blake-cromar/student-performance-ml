import json
import joblib
import numpy as np
import pandas as pd
import os
import logging
from azureml.core.model import Model

# Set up logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def init():
    global model
    try:
        model_path = os.path.join(os.getenv("AZUREML_MODEL_DIR"), "best_automl_model.pkl")
        logger.info(f"Model path resolved: {model_path}")
        model = joblib.load(model_path)
        logger.info("Model loaded successfully.")
    except Exception as e:
        logger.error(f"Error in init(): {str(e)}")
        raise

def run(raw_data):
    try:
        logger.info("Inference request received.")
        data = json.loads(raw_data)
        logger.info(f"Parsed input: {data}")

        df = pd.DataFrame(data)
        logger.info(f"Input converted to DataFrame with shape: {df.shape}")

        feature_columns = [
            "school", "sex", "age", "address", "famsize", "Pstatus", "Medu", "Fedu", 
            "Mjob", "Fjob", "reason", "guardian", "traveltime", "studytime", "failures",
            "schoolsup", "famsup", "paid", "activities", "nursery", "higher", "internet",
            "romantic", "famrel", "freetime", "goout", "Dalc", "Walc", "health", "absences",
            "G1", "G2"
        ]

        df = df[feature_columns]
        logger.info("Feature selection successful.")

        prediction = model.predict(df)
        logger.info(f"Prediction successful: {prediction.tolist()}")

        return json.dumps({"prediction": prediction.tolist()})
    
    except Exception as e:
        logger.error(f"Error during prediction: {str(e)}")
        return json.dumps({"error": str(e)})