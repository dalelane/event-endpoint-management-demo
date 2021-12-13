import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.CommonClientConfigs;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.config.SaslConfigs;

public class SampleApplication {
  public static final void main(String args[]) {
    Properties props = new Properties();

    props.put("bootstrap.servers", );
    props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
    props.put("value.deserializer", "org.apache.kafka.common.serialization.ByteArrayDeserializer");

    props.put("group.id", "1");
    props.put("client.id", );

    props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");

    props.put("auto.offset.reset", "earliest");
    props.put(SaslConfigs.SASL_MECHANISM, "PLAIN");
    props.put(SaslConfigs.SASL_JAAS_CONFIG, "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\" password=\"\";");
    props.put("ssl.truststore.location", "eventgateway.p12");
    props.put("ssl.truststore.type", "PKCS12");
    props.put("ssl.truststore.password", "password");
    props.put("ssl.endpoint.identification.algorithm", "");

    KafkaConsumer consumer = new KafkaConsumer<String, byte[]>(props);
    consumer.subscribe(Collections.singletonList("TWITTER.KAFKA"));
    try {
      while(true) {
        ConsumerRecords<String, byte[]> records = consumer.poll(Duration.ofSeconds(1));
        for (ConsumerRecord<String, byte[]> record : records) {
            byte[] value = record.value();
            String key = record.key();
            ObjectMapper om = new ObjectMapper();
            JsonNode jsonNode = om.readTree(value);

            // Do something with your JSON data
            Object somefield = jsonNode.get("Text");
            System.out.println(somefield);
          }
        }
    } catch (Exception e) {
      e.printStackTrace();
      consumer.close();
      System.exit(1);
    }
  }
}
