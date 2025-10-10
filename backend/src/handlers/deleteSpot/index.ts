import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, DeleteCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(
  new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-2" })
);

const PK = "ID";

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const id = event.pathParameters?.id;
    if (!id) {
      return { statusCode: 400, body: JSON.stringify({ error: "Missing path parameter: id" }) };
    }

    try {
      await ddb.send(new DeleteCommand({
        TableName: process.env.TABLE_NAME,
        Key: { ["ID"]: id },
        // If the item doesn't exist, this will throw ConditionalCheckFailedException
        ConditionExpression: "attribute_exists(#pk)",
        ExpressionAttributeNames: { "#pk": PK }
      }));

      return { statusCode: 204, body: "" }; // No Content
    } catch (err: any) {
      if (err.name === "ConditionalCheckFailedException") {
        return { statusCode: 404, body: JSON.stringify({ error: "Not found" }) };
      }
      console.error(err);
      return { statusCode: 500, body: JSON.stringify({ error: "Internal server error" }) };
    }
  } catch (err) {
    console.error(err);
    return { statusCode: 500, body: JSON.stringify({ error: "Internal server error" }) };
  }
};
