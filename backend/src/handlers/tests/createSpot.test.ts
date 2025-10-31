import { expect, test } from 'vitest'

const baseURL = "https://n7nrhon2c5.execute-api.us-east-2.amazonaws.com/dev"

test("Makes POST request to /spots endpoint (dev)", async () => {
    const res = await fetch(baseURL + "/create-spot", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
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
})