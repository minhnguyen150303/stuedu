const streamifier = require("streamifier");
const { cloudinary } = require("../config/cloudinary");

function uploadBufferToCloudinary(file, options = {}) {
    return new Promise((resolve, reject) => {
        const resourceType = options.resource_type || "auto";

        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: options.folder || "stu_edu",
                resource_type: resourceType,
                use_filename: true,
                unique_filename: true,
                display_name: file.originalname,
            },
            (error, result) => {
                if (error) return reject(error);
                resolve(result);
            }
        );

        streamifier.createReadStream(file.buffer).pipe(uploadStream);
    });
}

async function deleteCloudinaryFile(publicId, resourceType = "raw") {
    if (!publicId) return null;

    return await cloudinary.uploader.destroy(publicId, {
        resource_type: resourceType || "raw",
    });
}

module.exports = {
    uploadBufferToCloudinary,
    deleteCloudinaryFile,
};