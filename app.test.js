const request = require("supertest");
const app = require("./app");

describe("Get /health status", () => {
  it("should return status code 200 and status OK", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ status: "Healthy" });
  });
});
