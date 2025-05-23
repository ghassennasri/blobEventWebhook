from confluent_kafka import Consumer, KafkaError
import json
import os

def consume_events():
    """Consume events from Kafka topic"""
    consumer_config = {
    'bootstrap.servers': os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'pkc-5roon.us-east-1.aws.confluent.cloud:9092'),
    'security.protocol': 'SASL_SSL',
    'sasl.mechanisms': 'PLAIN',
    'sasl.username': os.environ.get('KAFKA_API_KEY', 'DPMLFBCUZVRUTSLU'),
    'sasl.password': os.environ.get('KAFKA_API_SECRET', 'sssssssssss'),
    'group.id': 'blob-event-consumer',
    'auto.offset.reset': 'earliest'
    }

    topic = os.environ.get('KAFKA_TOPIC', 'gna-blob-events')
    consumer = Consumer(consumer_config)
    consumer.subscribe([topic])

    print("Consuming events from Kafka topic 'blob-events'...")
    try:
        while True:
            msg = consumer.poll(timeout=10.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                else:
                    print(f"Consumer error: {msg.error()}")
                    break

            event_data = json.loads(msg.value().decode('utf-8'))
            print(f"Received event: {event_data['eventType']}, Blob: {event_data['subject']}")

    except KeyboardInterrupt:
        print("Stopping consumer...")
    finally:
        consumer.close()

if __name__ == "__main__":
    consume_events()