import { expect, test } from 'vitest'

const baseURL = "https://n7nrhon2c5.execute-api.us-east-2.amazonaws.com/dev"

test("Makes GET request to /spots endpoint (dev)", async () => {
  const res = await fetch(baseURL + "/spots");
  expect(res.status).toBe(200);
  const data = await res.json();
  expect(Array.isArray(data)).toBe(true);
})