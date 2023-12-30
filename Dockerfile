FROM ubuntu:latest

RUN apt-get update && apt-get install -y python3-pip

COPY ./src /home/src

RUN pip3 install --no-cache-dir -r /home/src/requirements.txt --break-system-packages

CMD ["python3", "/home/src/app.py"]
