#!/bin/sh
java -cp kafka-clients.jar:slf4j-api.jar:slf4j-nop.jar:jackson-databind.jar:jackson-core.jar:jackson-annotations.jar:. SampleApplication
