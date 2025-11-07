import { expect, test } from 'vitest'
import { getJwt } from "./tokens-ci.js";
import * as dotenv from "dotenv";

dotenv.config();

const baseURL = process.env.API_BASE;
let idToken: string;

test.beforeAll(async () => {
  idToken = await getJwt("id");
});

test("Makes POST request to /users endpoint (dev)", async () => {
    // crate a new spot
    const res = await fetch(baseURL + "/users", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
            displayName: "TestUser",
        })
    });
    expect(res.status).toBe(200);
    const data = await res.json();
})