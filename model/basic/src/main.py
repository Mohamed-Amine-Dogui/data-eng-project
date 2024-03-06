# import uvicorn
from fastapi import FastAPI

# from fastapi HTTPException
# from starlette.responses import Response
from typing import Optional
from pydantic import BaseModel


class PredictionRequest(BaseModel):
    """
    defines the shape of the "prediction request"
    """

    signalValue: str = None
    signalName: Optional[str] = None


app = FastAPI(debug=True, description="Serve model")


@app.get("/", status_code=200)
@app.get("/health", status_code=200)
def health_check():
    return "Healthy"


@app.post("/prediction", status_code=200)
def model_prediction(payload: PredictionRequest):
    response = {"echoedRequest": payload}
    return response


# if __name__ == "__main__":
#     # Add argparse
#     # if wanting to run uvicorn from here
#     uvicorn.run(host="0.0.0.0", port=80, ...)
