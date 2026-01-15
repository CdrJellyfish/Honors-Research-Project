Here is a comprehensive `README.md` file tailored for your GitHub repository. It synthesizes the technical details from your NetLogo source code and the theoretical context from your research report.

---

# Agent-Based Modeling of Chemotaxis in Competitive Heterogeneous Environments

## 📌 Project Overview

This repository contains a generalized **Agent-Based Model (ABM)** developed in **NetLogo 6.4.0**. The model simulates the microscopic interactions of bacterial communities driven by **chemotaxis**—the ability to sense and react to chemical gradients.

Predicting macroscopic microbial behaviors in heterogeneous, competitive environments is a complex challenge that traditional top-down mathematical models often fail to capture. This project bridges that gap by allowing population dynamics, spatial structures (such as swarming rings), and community stability to emerge from individual agent decisions.

The framework was validated against biological phenomena including logistic growth curves, chemotactic swarming patterns, and the principle of competitive exclusion.

## ✨ Key Features

* 
**Multi-Species Simulation:** Simulates 7 distinct bacterial species with unique parameters for speed, run/tumble duration, and metabolic needs.


* 
**Dynamic Chemical Environment:** Implements diffusion and decay for attractants (e.g., Glucose), repellents (e.g., Phenol), and signaling molecules (Autoinducer-2).


* 
**Complex Heterogeneity:** Supports diverse environments (e.g., Wound Sites, Soil Microcosms) and physical obstacles (e.g., Necrotic Tissue, Agar Walls) that block movement and chemical diffusion.


* 
**Competitive Dynamics:** Models resource competition and "chemical warfare" via toxin production (e.g., *P. polymyxa* producing Polymyxin B).


* 
**Biofilm Formation:** Agents can transition states from planktonic "running" to energy-efficient "biofilm" structures based on quorum sensing.



## 🚀 Getting Started

### Prerequisites

* 
**NetLogo 6.4.0**: You must have NetLogo installed to run the `.nlogo` file.



### Installation & Execution

1. **Clone the Repository:**
```bash
git clone https://github.com/your-username/chemotaxis-abm.git

```


2. 
**Verify File Structure:** Ensure `ChemtaxiSim.nlogo` is in the same folder as the required data files: `bacteria.csv`, `chemicals.csv`, `obstacles.csv`, and `environments.csv`.


3. **Launch the Model:**
* Open `ChemtaxiSim.nlogo` in NetLogo.
* Click the **`load-files`** button to import the CSV parameters.


* Select your environment and agents using the interface switches and sliders.
* Click **`setup`** to initialize the world.
* Click **`go`** to run the simulation.





## 🧬 Model Details

### 1. Bacterial Agents

The model simulates the following species, parameterized via `bacteria.csv`:

| Species | Gram Stain | Role/Notes |
| --- | --- | --- |
| *Escherichia coli* | Negative | Benchmark species, high motility.

 |
| *Pseudomonas aeruginosa* | Negative | Opportunistic pathogen, aerobic.

 |
| *Vibrio cholerae* | Negative | Pathogenic, high speed.

 |
| *Bacillus subtilis* | Positive | Soil dwelling, forms biofilms.

 |
| *Salmonella enterica* | Negative | Facultative anaerobe.

 |
| *Paenibacillus polymyxa* | Positive | Produces antibiotic Polymyxin B.

 |
| *Burkholderia cenocepacia* | Negative | Extremophile, resistant to stress.

 |

### 2. Chemical Effectors

Chemicals diffuse dynamically using NetLogo's `diffuse` primitive.

* **Attractants:** Glucose, Aspartate.
* **Repellents:** Phenol, Butanol, Polymyxin B (Toxin).
* 
**Signaling:** Autoinducer-2 (Quorum sensing for biofilms).



### 3. Environments & Obstacles

The simulation context changes based on `environments.csv` parameters, affecting viscosity (movement speed) and oxygen levels (metabolic efficiency).

* **Contexts:** Lab Agar Plate, Soil Microcosm, Wound Site (Hypoxic), Lake Water.
* 
**Obstacles:** Agar Walls, Polystyrene Beads, Necrotic Tissue, Oil Droplets.



## 🧪 Validation & Results

The model has been verified through several experiments detailed in the Research Report:

1. 
**Quantitative Validation:** Replicated the standard S-shaped logistic growth curve of a bacterial colony in a closed system.


2. 
**Qualitative Pattern Matching:** Successfully reproduced the emergent radial swarming ring patterns typical of *E. coli* colonies.


3. 
**Competitive Exclusion:** Demonstrated that toxin-producing *P. polymyxa* can effectively exclude *B. cenocepacia* from nutrient-rich zones.


4. 
**Complex Environments:** Simulated a hypoxic wound site where *S. enterica* (facultative) outcompeted *P. aeruginosa* (aerobic) amidst necrotic tissue obstacles.



## 📂 Repository Structure

```text
├── ChemtaxiSim.nlogo          # Main NetLogo Source Code
├── COS700_Research_Report.pdf # Full academic report & documentation
├── Data/
│   ├── bacteria.csv           # Agent parameters (Speed, metabolism, size)
│   ├── chemicals.csv          # Chemical diffusion/toxicity properties
│   ├── environments.csv       # Environmental context definitions
│   └── obstacles.csv          # Physical obstacle properties
└── README.md                  # Project documentation

```

## 👥 Credits

* 
**Author:** Jayson du Toit (u22571532) 


* 
**Supervisor:** Mr. W van Heerden 


* 
**Institution:** Department of Computer Science, University of Pretoria 


* 
**Date:** October 2025 



## 📄 License

This project is part of a university research report. Please cite the accompanying report (`COS700_Research_Report.pdf`) if utilizing this model for academic purposes.

---
