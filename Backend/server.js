const express = require("express");
const cors = require("cors");
require("dotenv").config();

const routes = require("./src/routes");
const { notFound, errorHandler } = require("./src/middlewares/error.middleware");
const { startScheduler } = require("./src/jobs/scheduler");

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => res.send("Backend OK"));

app.use("/api", routes);

app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    startScheduler();
});