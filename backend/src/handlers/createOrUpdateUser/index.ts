import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

// ----- Env -----
const REGION = process.env.AWS_REGION ?? "us-east-2";
const USERS_TABLE = process.env.USERS_TABLE ?? "Users";

// ----- AWS clients -----
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

// ----- Types -----
type JwtClaims = {
  sub: string;
  email?: string;
  email_verified?: boolean | string;
  name?: string;
  given_name?: string;
  "cognito:username"?: string;
  token_use?: string;
  [k: string]: unknown;
};

type RequestBody = {
  displayName?: string;
  profile?: Record<string, unknown>;
  // You can allow more fields here, but do not trust client for identity/email.
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*", // tighten in prod
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Content-Type": "application/json",
};

// ----- Helpers -----
const json = (statusCode: number, body: unknown): APIGatewayProxyResult => ({
  statusCode,
  headers: corsHeaders,
  body: JSON.stringify(body),
});

const parseBody = (raw: string | null): RequestBody => {
  if (!raw) return {};
  try {
    const b = JSON.parse(raw);
    if (b && typeof b === "object") {
      const out: RequestBody = {};
      if (typeof b.displayName === "string") out.displayName = b.displayName.trim();
      if (b.profile && typeof b.profile === "object") out.profile = b.profile;
      return out;
    }
    return {};
  } catch {
    throw new SyntaxError("Invalid JSON in request body");
  }
};

const toBool = (v: unknown) =>
  typeof v === "boolean" ? v : (typeof v === "string" ? v === "true" : undefined);

// ----- Handler -----
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // Allow CORS preflight without auth
    if (event.httpMethod === "OPTIONS") {
      return { statusCode: 204, headers: corsHeaders, body: "" };
    }

    // Require API Gateway JWT authorizer
    const claims = event.requestContext?.authorizer?.jwt?.claims as JwtClaims | undefined;
    if (!claims?.sub) {
      return json(401, { error: "Unauthorized: missing or invalid JWT claims" });
    }

    const userID = claims.sub;
    const email = typeof claims.email === "string" ? claims.email : undefined;
    const emailVerified = toBool(claims.email_verified);
    const cognitoUsername =
      (claims["cognito:username"] as string | undefined) ?? undefined;

    const body = parseBody(event.body ?? null);

    // Build the UpdateExpression dynamically for partial updates
    // Always set updatedAt; set createdAt only on first write.
    const nowIso = new Date().toISOString();

    const exprParts: string[] = ["updatedAt = :now"];
    const names: Record<string, string> = {};
    const values: Record<string, unknown> = { ":now": nowIso, ":created": nowIso };

    // Upsert immutable-ish identity fields from claims (only if not already present)
    exprParts.push(
      "userID = if_not_exists(userID, :uid)",
      "email = if_not_exists(email, :email)",
      "emailVerified = if_not_exists(emailVerified, :emailVerified)",
      "cognitoUsername = if_not_exists(cognitoUsername, :cogUser)",
      "tokenUse = if_not_exists(tokenUse, :tokenUse)",
      "createdAt = if_not_exists(createdAt, :created)"
    );
    values[":uid"] = userID;
    if (email !== undefined) values[":email"] = email;
    if (emailVerified !== undefined) values[":emailVerified"] = emailVerified;
    values[":cogUser"] = cognitoUsername ?? null;
    values[":tokenUse"] = (claims.token_use as string | undefined) ?? null;

    // Allow client-updatable fields (whitelist)
    if (typeof body.displayName === "string") {
      names["#displayName"] = "displayName";
      exprParts.push("#displayName = :displayName");
      values[":displayName"] = body.displayName;
    }
    if (body.profile && typeof body.profile === "object") {
      names["#profile"] = "profile";
      exprParts.push("#profile = :profile");
      values[":profile"] = body.profile;
    }
    //

    const cmd = new UpdateCommand({
      TableName: USERS_TABLE,
      Key: { userID },
      UpdateExpression: `SET ${exprParts.join(", ")}`,
      ExpressionAttributeNames: Object.keys(names).length ? names : undefined,
      ExpressionAttributeValues: values,
      ReturnValues: "ALL_NEW",
    });

    const result = await ddb.send(cmd);

    return json(200, {
      success: true,
      item: result.Attributes,
      message: "User created/updated successfully",
    });
  } catch (err: any) {
    if (err instanceof SyntaxError) {
      return json(400, { error: err.message });
    }
    console.error("Handler error:", err);
    return json(500, {
      error: err?.message ?? "Internal server error",
      type: err?.name ?? "Error",
    });
  }
};
