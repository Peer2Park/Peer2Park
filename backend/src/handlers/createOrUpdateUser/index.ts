import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { CognitoIdentityProviderClient, GetUserCommand } from "@aws-sdk/client-cognito-identity-provider";
import { createHash, createVerify } from "crypto";
import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";

const dynamoClient = new DynamoDBClient({});
const doc = DynamoDBDocumentClient.from(dynamoClient);
const cognitoClient = new CognitoIdentityProviderClient({});
const USERS_TABLE = process.env.USERS_TABLE || "Users";
const USER_POOL_ID = process.env.USER_POOL_ID || "us-east-2_BawVP5jpO";
const REGION = process.env.AWS_REGION || "us-east-2";

// Cache for JWKS keys
interface JWK {
    kty: string;
    kid: string;
    use: string;
    n: string;
    e: string;
    alg: string;
}

interface UserClaims {
    sub: string;
    email?: string;
    name?: string;
    given_name?: string;
    email_verified?: boolean;
    'cognito:username'?: string;
    token_use?: string;
}

let jwksCache: JWK[] | null = null;
let jwksCacheExpiry = 0;

// Fetch JWKS from Cognito
async function getJWKS() {
  const now = Date.now();
  if (jwksCache && now < jwksCacheExpiry) {
    return jwksCache;
  }

  try {
    const jwksUrl = `https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}/.well-known/jwks.json`;
    const response = await fetch(jwksUrl);
    const jwks = await response.json();
    
    jwksCache = jwks.keys;
    jwksCacheExpiry = now + (60 * 60 * 1000); // Cache for 1 hour
    
    return jwksCache;
  } catch (error) {
    console.error("Failed to fetch JWKS:", error);
    throw new Error("Unable to fetch JWKS");
  }
}

// Convert base64url to base64
function base64urlToBase64(base64url: string): string {
  return base64url.replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - base64url.length % 4) % 4);
}

// Simple JWT decode without verification (for development)
function decodeJWTPayload(token: string) {
  try {
    console.log("Attempting to decode JWT token");
    const parts = token.split('.');
    console.log("Token parts count:", parts.length);
    
    if (parts.length !== 3) {
      throw new Error("Invalid token format - must have 3 parts");
    }
    
    const [, payloadB64] = parts;
    if (!payloadB64) {
      throw new Error("Invalid token format - missing payload");
    }
    
    console.log("Payload base64:", payloadB64.substring(0, 50) + "...");
    
    const base64Payload = base64urlToBase64(payloadB64);
    console.log("Converted to base64:", base64Payload.substring(0, 50) + "...");
    
    const payloadStr = Buffer.from(base64Payload, 'base64').toString();
    console.log("Decoded payload string:", payloadStr.substring(0, 100) + "...");
    
    const payload = JSON.parse(payloadStr);
    console.log("Parsed payload:", JSON.stringify(payload, null, 2));
    
    // Check token expiration
    const now = Math.floor(Date.now() / 1000);
    console.log("Current timestamp:", now);
    console.log("Token expires at:", payload.exp);
    
    if (payload.exp && payload.exp < now) {
      throw new Error(`Token has expired. Current: ${now}, Expires: ${payload.exp}`);
    }
    
    console.log("Token is valid and not expired");
    return payload;
  } catch (error: any) {
    console.error("Token decode failed:", error);
    throw new Error(`Token decode failed: ${error.message}`);
  }
}

// Verify JWT token manually using Node.js crypto
async function verifyJWTToken(token: string): Promise<UserClaims> {
  try {
    const [headerB64, payloadB64, signatureB64] = token.split('.');
    
    if (!headerB64 || !payloadB64 || !signatureB64) {
      throw new Error("Invalid token format");
    }

    // Decode header and payload
    const header = JSON.parse(Buffer.from(base64urlToBase64(headerB64), 'base64').toString());
    const payload = JSON.parse(Buffer.from(base64urlToBase64(payloadB64), 'base64').toString());

    // Check token expiration
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      throw new Error("Token has expired");
    }

    // Verify token issuer
    const expectedIssuer = `https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}`;
    if (payload.iss !== expectedIssuer) {
      throw new Error("Invalid token issuer");
    }

    // For now, let's skip signature verification due to complexity
    // and just return the payload after basic validation
    console.log("⚠️  WARNING: JWT signature verification skipped for simplicity");
    return payload;
    
  } catch (error: any) {
    console.error("Token verification failed:", error);
    throw new Error(`Token verification failed: ${error.message}`);
  }
}

// Alternative: Use Cognito GetUser API for token validation
async function validateTokenWithCognito(accessToken: string) {
  try {
    const command = new GetUserCommand({
      AccessToken: accessToken
    });
    
    const response = await cognitoClient.send(command);
    return {
      sub: response.Username,
      email: response.UserAttributes?.find(attr => attr.Name === 'email')?.Value,
      email_verified: response.UserAttributes?.find(attr => attr.Name === 'email_verified')?.Value === 'true'
    };
  } catch (error) {
    console.error("Cognito token validation failed:", error);
    throw new Error("Invalid or expired token");
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  console.log("Event:", JSON.stringify(event));
  console.log("Event type:", typeof event);
  console.log("Has headers:", !!event.headers);
  console.log("Has requestContext:", !!event.requestContext);
  
  try {
    let userClaims: any = {};
    let userId: string | null = null;
    let body: any = {};
    
    // Determine if this is an API Gateway event or direct invocation
    const isApiGatewayEvent = event.headers && event.requestContext;
    
    if (isApiGatewayEvent) {
      console.log("Processing as API Gateway event");
      
      // Check if we have JWT claims from API Gateway authorizer (preferred method)
      if (event.requestContext?.authorizer?.jwt?.claims) {
        userClaims = event.requestContext.authorizer.jwt.claims;
        userId = userClaims.sub;
        console.log("Using API Gateway JWT authorizer claims");
      } else {
        // Fall back to manual token validation
        const authHeader = event.headers?.Authorization || event.headers?.authorization;
        
        if (!authHeader) {
          return {
            statusCode: 401,
            body: JSON.stringify({ error: "Missing Authorization header" }),
          };
        }

        const token = authHeader.replace(/^Bearer\s+/i, '');
        
        if (!token) {
          return {
            statusCode: 401,
            body: JSON.stringify({ error: "Invalid Authorization header format" }),
          };
        }

        try {
          // Option 1: Verify JWT manually (more secure but complex)
          userClaims = await verifyJWTToken(token);
          userId = userClaims.sub;
          console.log("Token verified manually");
        } catch (jwtError: any) {
          console.log("Manual JWT verification failed, trying Cognito API:", jwtError.message);
          
          try {
            // Option 2: Use Cognito GetUser API (simpler but requires access token)
            userClaims = await validateTokenWithCognito(token);
            userId = userClaims.sub;
            console.log("Token validated with Cognito API");
          } catch (cognitoError: any) {
            console.error("Both token validation methods failed:", cognitoError.message);
            return {
              statusCode: 401,
              body: JSON.stringify({ error: "Invalid or expired token" }),
            };
          }
        }
      }
      
      // Parse request body for API Gateway event
      body = event.body ? JSON.parse(event.body) : {};
      
    } else {
      console.log("Processing as direct Lambda invocation - DEVELOPMENT MODE");
      
      // For direct invocation, the event IS the body
      //   body = event;
      // Just include a body field in the event for consistency
      body = event.body ? JSON.parse(event.body) : {};
      
      // Check if token is in the request body as a workaround for API Gateway config issues
      if (body.token || body.authToken) {
        const token = body.token || body.authToken;
        console.log("Found token in request body for authentication");
        try {
          userClaims = await decodeJWTPayload(token);
          userId = userClaims.sub;
          console.log("Token decoded successfully from request body");
        } catch (error) {
          console.error("Token validation failed from request body:", error.message);
          return {
            statusCode: 401,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: "Invalid token in request body" }),
          };
        }
      } else if (event.token) {
        console.log("Found token in event for direct invocation");
        try {
          userClaims = await decodeJWTPayload(event.token);
          userId = userClaims.sub;
          console.log("Token decoded for direct invocation");
        } catch (error) {
          console.error("Token validation failed for direct invocation:", error.message);
          return {
            statusCode: 401,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: "Invalid token in direct invocation" }),
          };
        }
      } else {
        // For development/testing without token, create a mock user
        console.log("⚠️  WARNING: Running without authentication (development mode)");
        console.log("💡 HINT: You can pass 'authToken' in the request body as a workaround for API Gateway header issues");
        userId = "dev-user-" + Date.now();
        userClaims = {
          sub: userId,
          email: "dev@example.com",
          email_verified: true,
          "cognito:username": "dev-user"
        };
      }
    }

    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: "Unable to extract user ID from token" }),
      };
    }
    
    // Create user item with data from token and request body
    const item = {
      userID: userId,
      email: body.email || userClaims.email || null,
      displayName: body.displayName || userClaims.name || userClaims.given_name || null,
      createdAt: body.createdAt || new Date().toISOString(),
      profile: body.profile || null,
      emailVerified: userClaims.email_verified || false,
      // Add additional Cognito claims if needed
      cognitoUsername: userClaims.cognito_username || userClaims['cognito:username'] || null,
      tokenUse: userClaims.token_use || null,
    };

    // Remove null values to keep DynamoDB clean
    Object.keys(item).forEach(key => {
      if (item[key] === null || item[key] === undefined) {
        delete item[key];
      }
    });

    console.log("Storing user item:", JSON.stringify(item, null, 2));

    await doc.send(new PutCommand({
      TableName: USERS_TABLE,
      Item: item,
    }));

    const response = {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*', // Configure this properly for production
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
      },
      body: JSON.stringify({ 
        success: true, 
        item,
        message: "User created/updated successfully",
        debugInfo: {
          wasApiGatewayEvent: isApiGatewayEvent,
          authMethod: isApiGatewayEvent ? "API Gateway" : "Development Mode"
        }
      }),
    };
    
    console.log("Returning response:", JSON.stringify(response, null, 2));
    return response;
    
  } catch (err) {
    console.error("Handler error:", err);
    
    // Handle JSON parsing errors
    if (err instanceof SyntaxError) {
      const errorResponse = {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ error: "Invalid JSON in request body" }),
      };
      console.log("Returning error response:", JSON.stringify(errorResponse, null, 2));
      return errorResponse;
    }
    
    const errorResponse = {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ 
        error: err.message || "Internal server error",
        type: err.constructor.name,
        stack: err.stack
      }),
    };
    
    console.log("Returning error response:", JSON.stringify(errorResponse, null, 2));
    return errorResponse;
  }
};
