//
//  ParticleFilter.swift
//  fuckin_acceleration
//
//  Created by 皆川泰陽 on 2019/12/12.
//  Copyright © 2019 皆川泰陽. All rights reserved.
//

import Foundation
import CoreMotion


// 2*2の4次元でパーティクルを生成する
class ParticleFilter {
    private let alpha: Double
    private let sigma: Double
    private let particleCount: Int
    private var xResampled: [[Double]]
    private var likehoodsNormed: [Double]
    
    init(particleCount: Int, alpha: Double, sigma: Double) {
        self.particleCount = particleCount
        self.alpha = alpha
        self.sigma = sigma
        self.xResampled = ParticleFilter.generate_random_particles(particleCount: particleCount)
        self.likehoodsNormed = Array(repeating: 0.0, count: particleCount)
    }
    
    // 6次元の出力が来るので4次元に落とす
    public func run(input Acc: CMAcceleration, input Speed: [Double]) -> [Double] {
        let input = [Speed[0], Speed[1], Acc.x, Acc.y]
        let x = move_particles(particles: self.xResampled)
        self.likehoodsNormed = calurate_likelihood(particles: x, measuredPoint: input)
        resampling(particles: x, likelihoods: self.likehoodsNormed)
        system_noise()
        let m = self.likehoodsNormed.enumerated().max(by: { $0.element < $1.element })!
        return x[m.offset]
    }
    
    
    /*     ここからprivate      */
    
    private static func generate_random_particles(particleCount: Int) -> Array<Array<Double>> {
        var particles = Array(repeating: Array(repeating: 0.0, count: 4), count: particleCount)
        for i in particles.indices {
            for j in particles[0].indices {
                particles[i][j] = Double.random(in: -1 ... 1)
            }
        }
        return particles
    }
    
    private func move_particles(particles: [[Double]], seconds: Int = 1) -> [[Double]] {
        var particles = particles
        for i in particles.indices {
            for j in 0..<2 {
                particles[i][j] += particles[i][j+2]
            }
        }
        return particles
    }
    
    private func calurate_likelihood(particles: [[Double]], measuredPoint: [Double]) -> [Double] {
        let calGauss = { (particle: [Double]) -> Double in
            let left = 1.0/(pow(self.sigma, 4) * pow((2 * Double.pi), 2))
            var right = zip(particle, measuredPoint).reduce(0.0) { (Result, arg1) -> Double in
                let (p, m) = arg1
                return Result + pow((m - p), 2)
            }
            right = -1 * right / (2 * pow(self.sigma, 2))
            return left * exp(right)
        }
        var sum = 0.0
        var likelihoods = Array(repeating: 0.0, count: self.particleCount)
        for i in particles.indices {
            likelihoods[i] = calGauss(particles[i])
            sum += likelihoods[i]
        }
        for i in particles.indices {
            likelihoods[i] /= sum
        }
        return likelihoods
    }
    
    private func resampling(particles: [[Double]], likelihoods: [Double]) {
        var cumulativeSum = Array(repeating: likelihoods[0], count: self.particleCount + 1)
        for i in 1..<self.particleCount {
            cumulativeSum[i] = cumulativeSum[i-1] + likelihoods[i]
        }
        cumulativeSum[self.particleCount] = 100
        var rdm = Double.random(in: 0..<1) / Double(self.particleCount)
        var cumulativeIndex = 0
        for i in particles.indices {
            while cumulativeSum[cumulativeIndex] < rdm {
                cumulativeIndex += 1
            }
            for p in particles[cumulativeIndex].indices {
                self.xResampled[i][p] = particles[cumulativeIndex][p]
            }
            rdm += 1.0 / Double(self.particleCount)
        }
    }
    
    private func system_noise() {
        let ss = sqrt(self.sigma)
        for i in self.xResampled.indices {
            for j in self.xResampled[0].indices {
                let noise = self.alpha + ParticleFilter.box_muller() * ss
                self.xResampled[i][j] += noise
            }
        }
    }
    
    private static func box_muller() -> Double {
        let x = Double.random(in: 0...1)
        let y = Double.random(in: 0...1)
        let left = sqrt(-2.0 * log(x))
        let right = cos(2.0 * Double.pi * y)
        return left * right
    }
}
