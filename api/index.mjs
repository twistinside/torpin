import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';

const defaultClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const defaultTableName = process.env.TABLE_NAME ?? 'Torpin';
const responseHeaders = Object.freeze({
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json',
});

function getDurationInSeconds(startedAt, endedAt) {
  return Math.max(0, Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000));
}

function parseDate(value, fieldName) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid ${fieldName} value: ${value}`);
  }
  return date;
}

export function buildResponse(result) {
  return {
    body: JSON.stringify(result),
    headers: responseHeaders,
    statusCode: 200,
  };
}

export async function getLatestSession({ client, tableName }) {
  const output = await client.send(new QueryCommand({
    ExpressionAttributeValues: {
      ':recordType': 'sessionRecord',
    },
    KeyConditionExpression: 'recordType = :recordType',
    Limit: 1,
    ScanIndexForward: false,
    TableName: tableName,
  }));
  return output.Items?.[0] ?? null;
}

export function summarizeLatestSession(session, now) {
  if (session == null) {
    return {
      isBrianTorpin: false,
      recentlyTorpedAt: null,
      torpedForInSeconds: null,
    };
  }

  const startDate = parseDate(session.date, 'date');

  if (session.endDate == null) {
    return {
      isBrianTorpin: true,
      recentlyTorpedAt: now.toISOString(),
      torpedForInSeconds: getDurationInSeconds(startDate, now),
    };
  }

  const endDate = parseDate(session.endDate, 'endDate');

  return {
    isBrianTorpin: false,
    recentlyTorpedAt: endDate.toISOString(),
    torpedForInSeconds: getDurationInSeconds(startDate, endDate),
  };
}

export function createHandler({
  client = defaultClient,
  logger = console,
  now = () => new Date(),
  tableName = defaultTableName,
} = {}) {
  return async function handler(event = {}) {
    try {
      const result = summarizeLatestSession(
        await getLatestSession({ client, tableName }),
        now()
      );
      return buildResponse(result);
    } catch (error) {
      logger.error?.('Failed to check torpin status', error);
      throw error;
    }
  };
}

export const handler = createHandler();
