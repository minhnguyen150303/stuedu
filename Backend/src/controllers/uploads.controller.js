const { uploadBufferToCloudinary } = require("../services/uploads.service");

async function uploadSingle(req, res) {
    if (!req.file) {
        return res.status(400).json({ error: "File is required" });
    }

    const mimeType = req.file.mimetype || "";
    const isImage = mimeType.startsWith("image/");
    const resourceType = isImage ? "image" : "raw";

    const result = await uploadBufferToCloudinary(req.file, {
        folder: "stu_edu",
        resource_type: resourceType,
    });

    res.json({
        message: "Uploaded",
        url: result.secure_url,
        publicId: result.public_id,
        resourceType: result.resource_type,
        originalName: req.file.originalname,
        bytes: req.file.size,
        format: result.format || null,
    });
}

module.exports = { uploadSingle };