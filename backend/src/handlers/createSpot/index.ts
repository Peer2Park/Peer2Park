import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const client = new DynamoDBClient({region: "us-east-2"});
const dynamoDBClient = DynamoDBDocumentClient.from(client);

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;

        if (body.latitude === undefined || body.longitude === undefined) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: "latitude and longitude are required" }),
            };
        }

        const spotId = randomUUID();

        await dynamoDBClient.send(new PutCommand({
            TableName: "ParkingSpots",
            Item: {
                ID: spotId,
                Timestamp: Date.now(),
                Latitude: body.latitude,
                Longitude: body.longitude,
            },
        }));

        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Parking spot added!", id: spotId }),
        };
    } catch (err: any) {
        console.error(err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Internal server error", event }),
        };
    }
};
