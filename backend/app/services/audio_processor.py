import io
import os
import tempfile
import numpy as np
import scipy.io.wavfile as wavfile
import scipy.signal as signal
from typing import Dict, Any, Tuple

try:
    import soundfile as sf
    HAS_SOUNDFILE = True
except ImportError:
    HAS_SOUNDFILE = False

try:
    import librosa
    HAS_LIBROSA = True
except ImportError:
    HAS_LIBROSA = False

class AudioProcessor:
    """
    Real Audio Capture Preprocessing & Quality Validation Pipeline for VoiceShield.
    Converts input audio (WAV, MP3, M4A, AAC, OGG, FLAC) to canonical 16,000 Hz Mono WAV,
    performs peak normalization, enforces duration/signal quality checks, and returns metadata.
    """

    ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".aac", ".ogg", ".flac"}
    MAX_FILE_SIZE_MB = 25
    MIN_DURATION_SEC = 2.0
    MAX_DURATION_SEC = 120.0
    TARGET_SAMPLE_RATE = 16000
    TARGET_CHANNELS = 1

    def validate_file(self, filename: str, file_size: int) -> Tuple[bool, str]:
        ext = os.path.splitext(filename)[1].lower()
        if ext not in self.ALLOWED_EXTENSIONS:
            return False, f"Unsupported audio format '{ext}'. Allowed formats: {', '.join(self.ALLOWED_EXTENSIONS)}"
        
        max_bytes = self.MAX_FILE_SIZE_MB * 1024 * 1024
        if file_size > max_bytes:
            return False, f"File size exceeds maximum limit of {self.MAX_FILE_SIZE_MB} MB."
        
        if file_size < 100:
            return False, "Empty or corrupted audio file provided."

        return True, "File valid"

    def decode_audio(self, audio_bytes: bytes, filename: str) -> Tuple[np.ndarray, int, int]:
        """
        Decodes raw audio bytes into (float32 audio array, sample_rate, original_channels).
        Supports WAV, MP3, M4A via soundfile, librosa, or scipy.io.wavfile.
        """
        ext = os.path.splitext(filename)[1].lower()

        # Strategy 1: soundfile (fast, robust for WAV/FLAC/OGG/MP3)
        if HAS_SOUNDFILE:
            try:
                data, sr = sf.read(io.BytesIO(audio_bytes), dtype='float32')
                channels = 1 if data.ndim == 1 else data.shape[1]
                return data, sr, channels
            except Exception:
                pass

        # Strategy 2: librosa (handles MP3, M4A, AAC, WAV via soundfile/audioread)
        if HAS_LIBROSA:
            try:
                with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
                    tmp.write(audio_bytes)
                    tmp_path = tmp.name

                try:
                    data, sr = librosa.load(tmp_path, sr=None, mono=False)
                    if data.ndim == 1:
                        channels = 1
                        audio_data = data
                    else:
                        channels = data.shape[0]
                        audio_data = data.T  # Transpose to (samples, channels)
                    return audio_data, sr, channels
                finally:
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
            except Exception:
                pass

        # Strategy 3: scipy.io.wavfile for standard PCM WAV files
        try:
            sr, int_data = wavfile.read(io.BytesIO(audio_bytes))
            channels = 1 if int_data.ndim == 1 else int_data.shape[1]
            # Convert integer array to float32 normalized [-1.0, 1.0]
            if int_data.dtype == np.int16:
                float_data = int_data.astype(np.float32) / 32768.0
            elif int_data.dtype == np.int32:
                float_data = int_data.astype(np.float32) / 2147483648.0
            elif int_data.dtype == np.uint8:
                float_data = (int_data.astype(np.float32) - 128.0) / 128.0
            else:
                float_data = int_data.astype(np.float32)
            return float_data, sr, channels
        except Exception as e:
            raise ValueError(f"Audio file could not be decoded. Format '{ext}' may be unsupported or corrupted: {e}")

    def convert_to_mono(self, audio_data: np.ndarray) -> np.ndarray:
        """
        Converts multi-channel audio to single-channel Mono.
        """
        if audio_data.ndim == 1:
            return audio_data
        elif audio_data.ndim == 2:
            return np.mean(audio_data, axis=1)
        else:
            return audio_data.flatten()

    def resample(self, mono_audio: np.ndarray, orig_sr: int, target_sr: int = 16000) -> np.ndarray:
        """
        Resamples mono audio to target_sr (16,000 Hz).
        """
        if orig_sr == target_sr:
            return mono_audio

        if HAS_LIBROSA:
            return librosa.resample(y=mono_audio, orig_sr=orig_sr, target_sr=target_sr)

        # Polyphase resampling via scipy.signal
        num_output_samples = int(round(len(mono_audio) * float(target_sr) / orig_sr))
        return signal.resample(mono_audio, num_output_samples)

    def normalize(self, mono_audio: np.ndarray) -> np.ndarray:
        """
        Applies peak normalization (-0.95 to 0.95 range).
        """
        max_peak = np.max(np.abs(mono_audio))
        if max_peak > 0:
            return (mono_audio / max_peak) * 0.95
        return mono_audio

    def validate_quality_and_signal(self, mono_audio: np.ndarray, sample_rate: int) -> float:
        """
        Validates audio duration and checks for usable speech signal energy.
        """
        duration = len(mono_audio) / float(sample_rate)

        if duration < self.MIN_DURATION_SEC:
            raise ValueError(f"Audio is too short ({duration:.1f}s). Please record at least {self.MIN_DURATION_SEC:.0f} seconds.")

        if duration > self.MAX_DURATION_SEC:
            raise ValueError(f"Audio duration ({duration:.1f}s) exceeds maximum limit of {self.MAX_DURATION_SEC:.0f} seconds.")

        # Root Mean Square (RMS) signal energy calculation
        rms_energy = np.sqrt(np.mean(mono_audio ** 2))
        if rms_energy < 0.0005:
            raise ValueError("No usable speech audio detected in recording. Please record clearly.")

        return round(duration, 1)

    def export_canonical_wav_bytes(self, mono_audio: np.ndarray, sample_rate: int = 16000) -> bytes:
        """
        Encodes float32 mono audio array into canonical 16 kHz 16-bit PCM WAV bytes.
        """
        int16_data = (np.clip(mono_audio, -1.0, 1.0) * 32767.0).astype(np.int16)
        out_buffer = io.BytesIO()
        wavfile.write(out_buffer, sample_rate, int16_data)
        return out_buffer.getvalue()

    def process_and_validate(self, audio_bytes: bytes, filename: str) -> Tuple[bytes, Dict[str, Any]]:
        """
        Executes full audio preprocessing pipeline:
        Decode -> Mono Conversion -> 16kHz Resampling -> Normalization -> Quality Validation -> Canonical WAV Export.
        """
        # 1. Basic format/size check
        valid, err = self.validate_file(filename, len(audio_bytes))
        if not valid:
            raise ValueError(err)

        # 2. Decode audio
        audio_data, orig_sr, orig_channels = self.decode_audio(audio_bytes, filename)

        # 3. Convert to Mono
        mono_audio = self.convert_to_mono(audio_data)

        # 4. Resample to 16,000 Hz
        resampled_audio = self.resample(mono_audio, orig_sr, self.TARGET_SAMPLE_RATE)

        # 5. Quality & duration validation
        duration_sec = self.validate_quality_and_signal(resampled_audio, self.TARGET_SAMPLE_RATE)

        # 6. Peak Normalization
        normalized_audio = self.normalize(resampled_audio)

        # 7. Export canonical 16kHz Mono WAV bytes
        canonical_wav = self.export_canonical_wav_bytes(normalized_audio, self.TARGET_SAMPLE_RATE)

        metadata = {
            "duration_seconds": duration_sec,
            "original_sample_rate": orig_sr,
            "processed_sample_rate": self.TARGET_SAMPLE_RATE,
            "original_channels": orig_channels,
            "processed_channels": self.TARGET_CHANNELS,
            "format": "wav",
            "processing_status": "READY_FOR_MODEL"
        }

        return canonical_wav, metadata
