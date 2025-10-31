import { expect, test } from 'vitest'
import { getJwt } from "./tokens-ci.js";
import * as dotenv from "dotenv";

dotenv.config();

const baseURL = process.env.API_BASE;
let idToken: string;

test.beforeAll(async () => {
  idToken = await getJwt("id");
});

test("Makes DELETE request /spots/{id} endpoing (dev)", async () => {
    // First, create a spot to delete
    const createRes = await fetch(baseURL + "/create-spot", {
        method: "POST",
        headers: {
            Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
            latitude: 40.4237,
            longitude: -86.9212
        })
    });
    expect(createRes.status).toBe(200);
    const createData = await createRes.json();
    expect(createData).toHaveProperty("id");
    const spotId = createData.id;

    // Now, delete the created spot
    const deleteRes = await fetch(baseURL + `/spots/${spotId}`, {
        method: "DELETE",
        headers: {
            Authorization: `Bearer ${idToken}`,
        },
    });
    expect(deleteRes.status).toBe(204);

    // Finally, verify the spot has been deleted
    const getRes = await fetch(baseURL + "/spots", {
        method: "GET",
        headers: {
            Authorization: `Bearer ${idToken}`,
        }
    }
    );
    expect(getRes.status).toBe(200);
    const spots = await getRes.json();
    const found = spots.find((spot: any) => spot.ID === spotId);
    expect(found).toBeUndefined();
})