from flask import Flask, request, Response
import json
from confluent_kafka import Producer
import logging
import os

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Confluent Cloud Kafka configuration
kafka_config = {
    'bootstrap.servers': os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'pkc-5roon.us-east-1.aws.confluent.cloud:9092'),
    'security.protocol': 'SASL_SSL',
    'sasl.mechanisms': 'PLAIN',
    'sasl.username': os.environ.get('KAFKA_API_KEY', 'DPMLFBCUZVRUTSLU'),
    'sasl.password': os.environ.get('KAFKA_API_SECRET', 'V8EkN7ucSE55FuwuOCE53x24i0rMAYpUHFzwJIX0d7yXIJuA/FB5Fhn2ohOBPqUn')
}

# Kafka topic
kafka_topic = os.environ.get('KAFKA_TOPIC', 'gna-blob-events')

# Initialize Kafka producer
try:
    producer = Producer(kafka_config)
    logger.info("Kafka producer initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Kafka producer: {e}")
    producer = None

def delivery_report(err, msg):
    """Callback for Kafka message delivery"""
    if err is not None:
        logger.error(f'Message delivery failed: {err}')
    else:
        logger.info(f'Message delivered to {msg.topic()} [{msg.partition()}]')

@app.route('/api/updates', methods=['POST'])
def handle_event():
    """Handle incoming Blob Storage events from Event Grid"""
    try:
        # Log raw request data
        logger.info(f"Received request: {request.data}")
        events = request.get_json(force=True)  # Force JSON parsing
        if not events:
            logger.error("No JSON data in request")
            return Response(status=400)

        # Handle both single event and list of events
        if isinstance(events, dict):
            events = [events]
        elif not isinstance(events, list):
            logger.error(f"Invalid JSON format: expected dict or list, got {type(events)}")
            return Response(status=400)

        for event in events:
            # Log event data
            logger.info(f"Processing event: {json.dumps(event)}")

            # Handle Event Grid subscription validation
            if event.get('eventType') == 'Microsoft.EventGrid.SubscriptionValidationEvent':
                validation_code = event.get('data', {}).get('validationCode')
                if not validation_code:
                    logger.error("Validation event missing validationCode")
                    return Response(status=400)
                validation_response = {'validationResponse': validation_code}
                logger.info(f"Returning validation response: {validation_response}")
                return Response(json.dumps(validation_response), mimetype='application/json', status=200)

            # Process Blob Storage events
            if not producer:
                logger.error("Kafka producer not initialized")
                return Response(status=500)

            try:
                event_data = json.dumps(event)
                producer.produce(
                    kafka_topic,
                    key=event.get('id'),
                    value=event_data.encode('utf-8'),
                    callback=delivery_report
                )
                producer.poll(0)  # Trigger delivery callbacks
                logger.info(f"Processed event: {event.get('eventType')}")
            except Exception as e:
                logger.error(f'Error processing event: {e}')
                return Response(status=500)

        producer.flush()  # Ensure all messages are sent
        return Response(status=200)

    except Exception as e:
        logger.error(f"Error handling request: {e}")
        return Response(status=500)

# add test function to test sending a message to the Kafka topic
@app.route('/api/test', methods=['POST'])
def test_kafka():
    """Test sending a message to the Kafka topic"""
    try:
        test_message = request.get_json(force=True)
        if not test_message:
            logger.error("No JSON data in request")
            return Response(status=400)

        # Log test message
        logger.info(f"Sending test message: {json.dumps(test_message)}")

        if not producer:
            logger.error("Kafka producer not initialized")
            return Response(status=500)

        producer.produce(
            kafka_topic,
            key=test_message.get('id'),
            value=json.dumps(test_message).encode('utf-8'),
            callback=delivery_report
        )
        producer.flush()  # Ensure all messages are sent
        return Response(status=200)

    except Exception as e:
        logger.error(f"Error handling request: {e}")
        return Response(status=500)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8000)))
