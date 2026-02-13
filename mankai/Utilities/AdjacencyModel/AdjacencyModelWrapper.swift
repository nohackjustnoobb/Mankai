//
//  AdjacencyModelWrapper.swift
//  mankai
//
//  Created by Travis XU on 12/2/2026.
//

import CoreGraphics
import CoreImage
import CoreML
import Foundation
import UIKit

// MARK: - AdjacencyModelWrapper

class AdjacencyModelWrapper {
    /// The shared singleton instance.
    static let shared = try? AdjacencyModelWrapper()

    /// The expected input size for the model (width × height).
    private static let inputSize = CGSize(width: 224, height: 224)

    // MARK: - Properties

    private let model: AdjacencyModel
    private let ciContext = CIContext()

    // MARK: - Initialization

    private init() throws {
        Logger.adjacencyModel.debug("Initializing AdjacencyModelWrapper")
        model = try AdjacencyModel()
    }

    // MARK: - Prediction

    /// Run adjacency prediction on two image patches.
    ///
    /// - Parameters:
    ///   - image1: The left patch as a `UIImage`.
    ///   - image2: The right patch as a `UIImage`.
    /// - Returns: A `Double` in [0, 1]. Higher values indicate the patches are likely adjacent.
    /// - Throws: If preprocessing or inference fails.
    func predict(image1: UIImage, image2: UIImage) throws -> Double {
        let targetW = Int(Self.inputSize.width)
        let targetH = Int(Self.inputSize.height)

        guard let ci1 = image1.ciImage ?? image1.cgImage.map({ CIImage(cgImage: $0) }),
              let ci2 = image2.ciImage ?? image2.cgImage.map({ CIImage(cgImage: $0) })
        else {
            throw NSError(domain: "AdjacencyModel", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidInputImage")])
        }

        // Preprocess: crop then resize
        let processed1 = try preprocessLeftPatch(ci1, targetWidth: targetW, targetHeight: targetH)
        let processed2 = try preprocessRightPatch(ci2, targetWidth: targetW, targetHeight: targetH)

        // Convert to CVPixelBuffer
        let buffer1 = try createPixelBuffer(from: processed1, width: targetW, height: targetH)
        let buffer2 = try createPixelBuffer(from: processed2, width: targetW, height: targetH)

        // Build input
        let input = AdjacencyModelInput(image1: buffer1, image2: buffer2)

        // Run inference
        Logger.adjacencyModel.debug("Predicting adjacency for image pair")
        let output = try model.prediction(input: input)

        let score = output.adjacency_score[0].doubleValue
        Logger.adjacencyModel.debug("Prediction result: \(score)")
        return score
    }

    // MARK: - Preprocessing

    private func preprocessLeftPatch(
        _ image: CIImage, targetWidth: Int, targetHeight: Int
    ) throws -> CIImage {
        var ciImage = image
        let originalWidth = Int(ciImage.extent.width)

        // Crop: keep the rightmost `targetWidth` pixels
        if originalWidth > targetWidth {
            let cropX = originalWidth - targetWidth
            ciImage = ciImage.cropped(
                to: CGRect(
                    x: CGFloat(cropX),
                    y: 0,
                    width: CGFloat(targetWidth),
                    height: ciImage.extent.height
                )
            )
        }

        let translation = CGAffineTransform(translationX: -ciImage.extent.origin.x, y: -ciImage.extent.origin.y)
        ciImage = ciImage.transformed(by: translation)

        return try resizeToTarget(ciImage, targetWidth: targetWidth, targetHeight: targetHeight)
    }

    private func preprocessRightPatch(
        _ image: CIImage, targetWidth: Int, targetHeight: Int
    ) throws -> CIImage {
        var ciImage = image
        let originalWidth = Int(ciImage.extent.width)

        // Crop: keep the leftmost `targetWidth` pixels
        if originalWidth > targetWidth {
            ciImage = ciImage.cropped(
                to: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(targetWidth),
                    height: ciImage.extent.height
                )
            )
        }

        let translation = CGAffineTransform(translationX: -ciImage.extent.origin.x, y: -ciImage.extent.origin.y)
        ciImage = ciImage.transformed(by: translation)

        return try resizeToTarget(ciImage, targetWidth: targetWidth, targetHeight: targetHeight)
    }

    private func resizeToTarget(
        _ ciImage: CIImage, targetWidth: Int, targetHeight: Int
    ) throws -> CIImage {
        let scaleX = CGFloat(targetWidth) / ciImage.extent.width
        let scaleY = CGFloat(targetHeight) / ciImage.extent.height

        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        return scaled
    }

    // MARK: - Pixel Buffer

    private func createPixelBuffer(from image: CIImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(domain: "AdjacencyModel", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "failedToCreatePixelBuffer")])
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        ciContext.render(image, to: buffer)

        return buffer
    }
}
