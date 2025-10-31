import { expect, test } from 'vitest'
import { getJwt } from "./tokens-ci.js";
import * as dotenv from "dotenv";

dotenv.config();

const baseURL = process.env.API_BASE;
let idToken: string;

test.beforeAll(async () => {
  idToken = await getJwt("id");
});

test("Makes POST request to /spots endpoint (dev)", async () => {
    // crate a new spot
    const res = await fetch(baseURL + "/create-spot", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
            latitude: 40.4237,
            longitude: -86.9212
        })
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data).toHaveProperty("message", "Parking spot added!");
    expect(data).toHaveProperty("id");

    // delete the created spot to clean up
    const spotId = data.id;
    const deleteRes = await fetch(baseURL + `/spots/${spotId}`, {
        method: "DELETE",
        headers: {
            Authorization: `Bearer ${idToken}`,
        },
    });
    expect(deleteRes.status).toBe(204);
})