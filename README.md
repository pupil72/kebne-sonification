# Kebne-sonification

Real-time, EDM-inspired sonification of supercomputer activity using SuperCollider and OSC.

This project transforms live monitoring data from the Kebnekaise supercomputer into a continuously evolving electronic dance music track. Instead of visual dashboards, the system provides an auditory representation of the machine's activity through sound.

The project will be presented at the 31st International Conference on Auditory Display in the paper "Real-Time, EDM-Inspired Sonification of the Activity of a Supercomputer" by Marco Alunno and Paolo Bientinesi.

---

## Overview

Monitoring data from the Kebnekaise supercomputer at HPC2N is forwarded to SuperCollider via OSC and converted into a continuously changing EDM track. The system operates autonomously — no user interaction is required beyond launching it. A GUI allows muting and unmuting individual instrument layers. This repository contains only the SuperCollider code and a sound folder to be used with it.

The sonification runs at 128 BPM and refreshes approximately every 15 seconds with new data batches.

---

## Sonification Strategy

Each partition of the supercomputer is mapped to a layer of the EDM track — kick drum, snare, hi-hats, clap, shaker, bass, sub bass, chords, vocal layers, and more.

Three metrics drive the musical mapping:

| Data stream	  | Parameter mapping 	   | Polarity 		                 |
|---------------|------------------------|-------------------------------|
| \procs  	    | rhythmic density 	     |+procs	   -> +density	       |
| \memusage  	  | pitch / playback speed |+memusage -> higher pitch      |
| \IB-tx  	    | reverb and delay	     |+IB-tx	   -> +reverb and delay|

---

## Monitoring Modes

**Full Display** — all layers play simultaneously, allowing direct monitoring of all partitions at once.

**Round-Robin** — layers move sequentially into the foreground for focused listening while others are attenuated.

---

## Running the Project

**Requirements:** SuperCollider.

**Launch:** run main.scd.

---

## Citation

If you use or reference this project, please cite:

> Marco Alunno and Paolo Bientinesi.
> *"Real-Time, EDM-Inspired Sonification of the Activity of a Supercomputer."*
> Proceedings of the 31st International Conference on Auditory Display (ICAD 2026).

---

## License

[Creative Commons Attribution-NonCommercial 4.0 International License](https://creativecommons.org/licenses/by-nc/4.0/)

---

## Acknowledgements

Developed with the support of Universidad EAFIT, Umeå University, and High-Performance Computing Center North. Special thanks to Åke Sandgren and Mickaël Zehren for their contributions and feedback.
