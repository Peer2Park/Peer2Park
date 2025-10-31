import { expect, test } from 'vitest'

const baseURL = "https://n7nrhon2c5.execute-api.us-east-2.amazonaws.com/dev"

test("Makes DELETE request /spots/{id} endpoing (dev)", async () => {
    // First, create a spot to delete
    const createRes = await fetch(baseURL + "/create-spot", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
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
        method: "DELETE"
    });
    expect(deleteRes.status).toBe(204);

    // Finally, verify the spot has been deleted
    const getRes = await fetch(baseURL + "/spots");
    expect(getRes.status).toBe(200);
    const spots = await getRes.json();
    const found = spots.find((spot: any) => spot.ID === spotId);
    expect(found).toBeUndefined();
})