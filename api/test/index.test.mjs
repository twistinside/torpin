import assert from 'node:assert/strict';
import test from 'node:test';

import { buildResponse, createHandler, getLatestSession, summarizeLatestSession } from '../index.mjs';

function makeClient({ error, items } = {}) {
  const calls = [];

  return {
    calls,
    async send(command) {
      calls.push(command.input);
      if (error) {
        throw error;
      }
      return { Items: items };
    },
  };
}

function makeLogger() {
  return {
    error() {},
    info() {},
  };
}

test('buildResponse returns the public API contract', () => {
  assert.deepEqual(buildResponse({
    isBrianTorpin: true,
    recentlyTorpedAt: '2026-03-27T10:00:00.000Z',
    torpedForInSeconds: 42,
  }), {
    body: '{"isBrianTorpin":true,"recentlyTorpedAt":"2026-03-27T10:00:00.000Z","torpedForInSeconds":42}',
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    },
    statusCode: 200,
  });
});

test('getLatestSession checks the newest session record only', async () => {
  const client = makeClient({
    items: [{ date: '2026-03-27T00:00:00Z' }],
  });

  const latestSession = await getLatestSession({ client, tableName: 'Torpin' });

  assert.deepEqual(latestSession, { date: '2026-03-27T00:00:00Z' });
  assert.deepEqual(client.calls, [{
    ExpressionAttributeValues: {
      ':recordType': 'sessionRecord',
    },
    KeyConditionExpression: 'recordType = :recordType',
    Limit: 1,
    ScanIndexForward: false,
    TableName: 'Torpin',
  }]);
});

test('summarizeLatestSession returns null fields when no history exists', () => {
  assert.deepEqual(
    summarizeLatestSession(null, new Date('2026-03-27T10:00:00.000Z')),
    {
      isBrianTorpin: false,
      recentlyTorpedAt: null,
      torpedForInSeconds: null,
    }
  );
});

test('summarizeLatestSession returns active session metadata', () => {
  assert.deepEqual(
    summarizeLatestSession(
      { date: '2026-03-27T09:59:00.000Z' },
      new Date('2026-03-27T10:00:30.000Z')
    ),
    {
      isBrianTorpin: true,
      recentlyTorpedAt: '2026-03-27T10:00:30.000Z',
      torpedForInSeconds: 90,
    }
  );
});

test('handler returns completed-session metadata when the newest session is closed', async () => {
  const client = makeClient({
    items: [{ date: '2026-03-27T00:00:00Z', endDate: '2026-03-27T01:00:00Z' }],
  });
  const handler = createHandler({
    client,
    logger: makeLogger(),
    now: () => new Date('2026-03-27T10:00:30.000Z'),
    tableName: 'Torpin',
  });

  const response = await handler({
    path: '/v2',
    requestContext: { requestId: 'request-123' },
  });

  assert.deepEqual(response, {
    body: '{"isBrianTorpin":false,"recentlyTorpedAt":"2026-03-27T01:00:00.000Z","torpedForInSeconds":3600}',
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    },
    statusCode: 200,
  });
});

test('handler rethrows DynamoDB failures', async () => {
  const error = new Error('boom');
  const handler = createHandler({
    client: makeClient({ error }),
    logger: makeLogger(),
    tableName: 'Torpin',
  });

  await assert.rejects(async () => {
    await handler();
  }, error);
});
