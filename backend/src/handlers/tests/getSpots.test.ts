import { expect, test } from 'vitest'
import { getJwt } from "./tokens-ci.js";
import * as dotenv from "dotenv";

dotenv.config();

const baseURL = process.env.API_BASE;
let idToken: string;

test.beforeAll(async () => {
  idToken = await getJwt("id");
});

test("Makes GET request to /spots endpoint (dev)", async () => {
  const res = await fetch(baseURL + "/spots", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${idToken}`,
    },
  });
  expect(res.status).toBe(200);
  const data = await res.json();
  expect(Array.isArray(data)).toBe(true);
})