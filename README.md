# Real-Time Audio Noise Classifier and Automatic Adaptive Filter System

![Language](https://img.shields.io/badge/Language-MATLAB-blue?style=flat-square)
![Domain](https://img.shields.io/badge/Domain-DSP_Audio_Processing-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Verified-success?style=flat-square)

**Date:** December 24, 2025  
**Version:** 1.0  
**Status:** Final Release

---

## 1. Project Metadata

| Category | Details |
| :--- | :--- |
| **Project Title** | Real-Time Audio Noise Classifier and Adaptive Filter System |
| **Authors** | **Muhammad Qasim** (2023488) <br> **Muhammad Hammad** (2023420) |
| **Institution** | Department of Computer Engineering, Ghulam Ishaq Khan Institute (GIKI), Topi, Pakistan |
| **Domain** | Digital Signal Processing (DSP), Audio Engineering, Adaptive Filtering |

---

## 2. Executive Summary

This project presents a sophisticated audio processing pipeline designed to mitigate environmental noise pollution in real-time recordings. Unlike traditional systems that utilize static filtering techniques—which often degrade audio fidelity by applying a blanket frequency cut—this system functions as an intelligent agent.

The system autonomously analyzes the acoustic environment to classify the specific noise topology (e.g., electrical hum versus wind noise). Subsequently, it adapts by engaging the mathematically optimal filter designed specifically for the identified interference, thereby preserving the integrity of the desired signal.



---

## 3. Detailed System Architecture

The system architecture is bifurcated into two distinct, serial processing modules: the **Classification Module** (Signal Analysis) and the **Filtering Module** (Signal Restoration).

### Module 1: Classification Subsystem ("The Brain")

The primary objective of this module is to acquire raw audio data and deterministically identify the noise signature through spectral analysis.

#### A. Signal Acquisition
The system captures audio utilizing high-fidelity parameters to ensure the digital signal serves as an accurate representation of the analog environment:

* **Sampling Frequency ($f_s$):** $44.1 \text{ kHz}$. This adheres to the industry standard for high-resolution audio, satisfying the Nyquist-Shannon sampling theorem for frequencies up to $22.05 \text{ kHz}$.
* **Bit Depth:** 16-bit. This specification provides a dynamic range of $96 \text{ dB}$, minimizing quantization noise for both high and low-amplitude signals.
* **Channel Configuration:** Mono. Processing is restricted to a single channel to optimize computational resources for spectral analysis rather than spatial stereo processing.
* **Duration:** Segments of 3 to 5 seconds are captured for near real-time latency.



#### B. Pre-Processing & Normalization
To ensure analytical accuracy, the raw signal undergoes signal conditioning prior to feature extraction:

1.  **DC Offset Removal:** The mean amplitude is subtracted from the signal ($y = y_{raw} - \mu$) to center the waveform at zero, eliminating electrical bias.
2.  **Amplitude Normalization:** The signal is scaled such that the peak amplitude resides within the range $[-0.9, 0.9]$. This normalization is critical for ratio-based decision logic, preventing skew caused by variable input gain.

**Normalization Equation:**
$$y_{norm}[n] = \frac{y[n]}{\max(|y[n]|)} \times 0.9$$

#### C. Feature Extraction
The system utilizes the **Fast Fourier Transform (FFT)** to transpose the signal from the Time Domain (waveform) to the Frequency Domain (spectrum). Three primary features are extracted:



**1. Spectral Centroid**
This metric represents the "center of mass" of the spectrum, indicating the dominant frequency range (timbre).

**Formula:**
$$C = \frac{\sum_{k} f[k] \cdot |X[k]|}{\sum_{k} |X[k]|}$$

* **Logic:** A low centroid ($< 300 \text{ Hz}$) indicates Wind or Traffic. A high centroid indicates Speech or Fan Hiss.

**2. Band Power Ratios**
Energy distribution is calculated across specific frequency bins relative to total signal power:
* **Hum Band (45–65 Hz):** Targets mains electricity interference ($50 \text{ Hz}$ standard).
* **Low Band (20–300 Hz):** Targets mechanical rumble and wind buffeting.
* **Mid Band (300–3400 Hz):** Targets the human vocal range.

**3. Silence Detection**
Total signal power is evaluated against a noise floor threshold ($0.001$). Signals below this threshold are classified as **Silence**, bypassing the filtering stage to conserve resources.

#### D. Decision Logic
A deterministic decision tree classifies the noise based on the extracted feature set:

1.  **Silence Check:** If $\text{Total Power} < 0.001 \rightarrow$ **Label: Silence**
2.  **Hum Check:** If $\text{Ratio}_{Hum} > 0.1 \rightarrow$ **Label: Electrical Hum**
3.  **Speech Check:** If $\text{Ratio}_{Mid} > 0.45 \rightarrow$ **Label: Human Chatter**
4.  **Low Frequency Check:** If $\text{Ratio}_{Low} > 0.4$:
    * If $\text{Centroid} < 300 \text{ Hz} \rightarrow$ **Label: Wind Noise**
    * Else $\rightarrow$ **Label: Traffic Noise**
5.  **Default:** $\rightarrow$ **Label: Fan Noise**

---

### Module 2: Adaptive Filtering Subsystem ("The Action")

Upon identification of the noise class, the system activates a specific digital filter tailored to remove the interference while preserving the desired audio.

#### 1. Scenario: Electrical Hum Detected
* **Problem:** Persistent tonal interference at $50 \text{ Hz}$ caused by power line electromagnetic interference.
* **Solution:** Cascaded IIR Notch Filters.
* **Implementation:** Three precise notches are applied in series to attenuate the fundamental frequency and its first two harmonics:
    1.  $50 \text{ Hz}$ (Fundamental)
    2.  $100 \text{ Hz}$ (1st Harmonic)
    3.  $150 \text{ Hz}$ (2nd Harmonic)
* **Rationale:** Unlike low-pass filters, notch filters act surgically, removing only the interference frequencies without affecting the surrounding audio spectrum.



#### 2. Scenario: Wind Noise Detected
* **Problem:** Non-stationary "buffeting" or "rumble" caused by air turbulence on the microphone diaphragm, characterized by high energy in low frequencies.
* **Solution:** 6th-Order Butterworth High-Pass Filter.
* **Implementation:** A steep filter with a cutoff at $200 \text{ Hz}$.
* **Technical Note:** While the initial design proposed an NLMS (Normalized Least Mean Squares) adaptive algorithm, the final implementation utilizes a Butterworth filter to ensure stability on short audio segments. The Butterworth design provides a maximally flat passband and sharp rolloff.

#### 3. Scenario: Traffic or Engine Noise Detected
* **Problem:** Continuous low-frequency drone.
* **Solution:** Aggressive High-Pass Filter.
* **Implementation:** A high-pass filter with a cutoff at $400 \text{ Hz}$ and a steepness factor of $0.85$. This eliminates the engine drone while preserving speech intelligibility (which resides primarily above $400 \text{ Hz}$).



#### 4. Scenario: Fan or Broadband Noise Detected
* **Problem:** "White noise" hiss distributed across the spectrum.
* **Solution:** Voice-Band Band-Pass Filter.
* **Implementation:** Frequencies outside the range of $300 \text{ Hz}$ to $3400 \text{ Hz}$ are attenuated. This isolates the human voice band, effectively discarding high-pitched hiss and low-pitched rumble.

#### 5. Automatic Gain Control (AGC)
Post-filtering, the signal amplitude often decreases due to the removal of noise energy. The system calculates the new peak amplitude and applies a gain factor to normalize the output to $0.95$ ($95\%$ volume), ensuring audible clarity.

---

## 4. Visualizations & Output

The system generates immediate visual feedback to validate performance:

1.  **Command Window:** Displays computed spectral ratios (e.g., `Ratio Hum: 0.12`) and the resulting classification (e.g., `FINAL DECISION: ** Electrical Hum **`).
2.  **Time Domain Plot:** Overlays the **Original (Noisy)** waveform (Red) and the **Filtered (Clean)** waveform (Blue), visualizing amplitude reduction.
3.  **Frequency Spectrum Plot:** Displays power distribution. Successful filtering is visible as specific reductions in the noise bands (e.g., a notch at $50 \text{ Hz}$).

---

## 5. User Manual: Execution Guide

### Requirements
* **Hardware:** PC with an external or internal microphone.
* **Software:** MATLAB with the **DSP System Toolbox** installed.

### Execution Steps
1.  Open MATLAB and navigate to the project directory.
2.  Run the script `Final.m`.
3.  Observe the command prompt for the cue: `>> ACTION: Make noise!`.
4.  You have a **3-second window** to simulate noise (e.g., hum, blow into the mic, or speak).
5.  The system will record, process, and sequentially play back the **Original** audio followed by the **Cleaned** audio.

---

## 6. Mathematical Foundations

The system relies on the following mathematical principles for analysis and adaptive learning:

**Zero Crossing Rate (ZCR):**
Used in time-domain analysis to estimate signal periodicity.

$$ZCR = \frac{1}{2N}\sum_{n=1}^{N}|sgn(y[n]) - sgn(y[n-1])|$$

**NLMS Weight Update:**
The theoretical basis for adaptive filtering algorithms (initially proposed for wind noise cancellation).

$$w[n+1] = w[n] + \mu\frac{e[n]x[n]}{||x[n]||^{2}+\epsilon}$$

**Where:**
* $\mu$: Step size (learning rate).
* $e[n]$: Error signal.
* $\epsilon$: Regularization term to prevent division by zero.

---

## 7. Conclusion

This project demonstrates a fully functional **"Smart Audio System."** By synthesizing spectral feature extraction with a deterministic decision tree, the system automates the complex task of audio cleaning. Results indicate that identifying the *type* of noise is a prerequisite for effective restoration, allowing for a targeted filtering approach that preserves audio quality significantly better than static, general-purpose filters.
