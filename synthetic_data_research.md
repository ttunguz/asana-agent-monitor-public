---

# Building Domain-Specific Models for Synthetic Data Generation: Research Summary

## Executive Summary

Based on recent academic work (2024-2025), building domain-specific models for synthetic data generation—particularly for tool calling—involves several key strategies:

1. LLM-based approaches with domain grounding
2. Conditional diffusion models with fine-tuning
3. Quality-first data generation & validation
4. Iterative refinement with active learning

## 1. Tool Calling: Quality Over Quantity

**Key Finding (arXiv 2409.16341: "Quality Matters")**
Models trained on high-quality data outperform those trained on unvalidated data, even with smaller datasets.

**Methodology:**
- Human-defined correctness criteria: Rule-based quality assessment
- Model-driven assessment: In-context evaluation for automated checking
- Validation before training: Systematic quality checks prevent poor downstream performance

**Practical Implications:**
- Generate fewer, higher-quality tool-calling examples
- Validate API call correctness, parameter types & response handling
- Use both automated validation & human review

## 2. Domain-Specific Approaches for LLMs

### A. Multi-Stage Domain-Grounded Generation (arXiv 2509.25736)

**Pipeline:**
1. Retriever: Fetch relevant domain knowledge (structured knowledge graphs)
2. Base Generator: Create initial synthetic examples
3. Refinement Model: Use domain-specific knowledge to improve quality

Applied to telecommunications domain with strong results

### B. Granular Context Generation (arXiv 2502.17957)

**Strategy for Domain-Specific Retrieval:**
- Generate queries at multiple granularities (sentence-level, chunk-level, document-level)
- Add domain-relevant constraints derived from metadata
- Use two-stage training:
  1. Learn document identifiers with LLM-generated multi-granular queries
  2. Refine rankings via hard negative mining from initial predictions

Avoids manual annotation while maintaining domain relevance

### C. Active Synthetic Data Generation (arXiv 2512.00884)

**Key Innovation:**
- Closed-loop generation: Generate data conditioned on samples prioritized by active learning
- Iterative refinement: Student model's current state guides next generation batch
- Resource-aware strategies:
  - Low query budget → augment existing answers
  - High query budget → generate new questions

## 3. Diffusion Models: Getting Them to Focus on Domains

### The Challenge
> "Diffusion models provide broad distribution coverage, but how do you narrow focus to a specific domain?"

**Answer: Fine-Tuning & Conditional Generation**

### A. Domain Adaptation via Fine-Tuning (arXiv 2306.14153: DomainStudio)

**Problem:** Standard diffusion models overfit on limited domain data, losing diversity

**Solution:**
- Start with pre-trained DDPM on large-scale source dataset
- Fine-tune on limited target domain data
- Use regularization techniques to maintain source diversity while adapting to target

**Result:** High-quality, diverse samples in target domain without catastrophic forgetting

### B. Conditional Control Mechanisms

**Three Primary Approaches:**

1. **Cross-Attention Conditioning**
   - Inject domain-specific signals via cross-attention layers
   - Model selectively focuses on relevant domain features
   - Used in Stable Diffusion, DALL-E variants

2. **Classifier Guidance**
   - Train domain classifier alongside diffusion model
   - Use gradient from classifier to guide denoising toward target domain
   - Can combine multiple classifiers for multi-domain control

3. **Training-Free Knowledge Alignment (2025 Geophysical Research)**
   - Embed domain-specific knowledge into sampling process
   - No retraining required
   - Particularly effective for scientific domains with known constraints

### C. Pretraining in the Domain

**Two Strategies:**

1. **Domain-Specific Pretraining from Scratch**
   - Train diffusion model entirely on domain data
   - Most effective when ample domain data exists
   - Avoids distribution mismatch issues

2. **Continued Pretraining (Hybrid Approach)**
   - Start with general pretrained model
   - Continue pretraining on domain corpus
   - Balances general knowledge with domain specificity

## 4. Distribution Narrowing: The Key Trade-off

### The Problem (arXiv 2402.04929, 2312.02253)

Synthetic images differ from real data:
- Features are nearly separable in embedding space
- Risk of overfitting when synthetic data dominates training
- Performance degradation despite high visual quality

**Root Cause:** Models learn synthetic artifacts rather than real-world patterns

### Solutions

1. **Synthetic-Domain Alignment**
   - Fine-tune source model on synthetic data to ensure alignment
   - Use auxiliary batch normalization treating real & synthetic as separate domains

2. **Diversification Techniques**
   - Mix real & synthetic data
   - Use multiple generation seeds
   - Apply data augmentation to synthetic samples

3. **Source-Free Domain Adaptation (DM-SFDA)**
   - Fine-tune diffusion model to generate source-like images using target data
   - Minimize entropy & maximize confidence for pre-trained source model
   - Avoids need for source data access

## 5. Practical Framework for Tool-Calling Synthetic Data

### Recommended Pipeline

```
┌─────────────────────────────────────────────────────────┐
│ Step 1: Domain Knowledge Extraction                     │
│ - API documentation, examples, schemas                  │
│ - Tool specifications & constraints                     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Step 2: Multi-Granular Generation                       │
│ - Task-level: High-level goals requiring tool chains   │
│ - Function-level: Individual API calls                 │
│ - Parameter-level: Valid argument combinations         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Step 3: Quality Validation (CRITICAL)                   │
│ - Syntax validation (parseable API calls)              │
│ - Semantic validation (correct tool for task)          │
│ - Execution validation (actually works)                │
│ - Human spot-checks (sample-based review)              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Step 4: Hard Negative Mining                            │
│ - Train initial model on validated data                │
│ - Identify error patterns                              │
│ - Generate targeted examples for weak areas            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Step 5: Iterative Refinement                            │
│ - Active learning to prioritize next generation batch  │
│ - Continuous quality monitoring                        │
│ - Domain expert feedback loop                          │
└─────────────────────────────────────────────────────────┘
```

## 6. Diffusion vs. LLM Approaches for Tool Calling

### When to Use Diffusion Models
- Structured outputs with continuous embeddings (e.g., code embeddings, API parameter spaces)
- Large-scale generation with diverse sampling
- Multi-modal tasks (combining text, images, structured data)

### When to Use LLMs
- Discrete symbolic generation (API calls, JSON schemas)
- Rapid prototyping with prompt engineering
- Few-shot adaptation to new tools
- Natural language to API translation

### Hybrid Approach (Recommended)
- LLM for initial generation → Fast, interpretable, easy to validate
- Diffusion for data augmentation → Adds diversity, explores parameter space
- LLM for filtering & refinement → Ensures quality & correctness

## 7. Key Tools & Frameworks (2024-2025)

**DataDreamer (ACL 2024, arXiv 2402.10379)**
- Open-source Python library for LLM workflows
- Supports synthetic data generation, fine-tuning, evaluation
- Emphasizes reproducibility & best practices
- GitHub: datadreamer-dev/datadreamer

**Curator (Mentioned in surveys)**
- Facilitates synthesis of reasoning, code execution, chart generation & function-calling data
- Supports diverse downstream fine-tuning tasks

**SDG Hub (Red Hat Developer, 2024)**
- Specialized for building domain-specific LLMs with synthetic data
- Integrated workflows for data generation & validation

## 8. Answer to Core Question

> "How would one build a domain-specific model for synthetic data generation, especially for tool calling?"

### Recipe

1. **Start with a strong foundation model** (GPT-4, Claude, Llama 3)
   - Provides general API understanding & code generation ability

2. **Create domain-specific grounding data**
   - Tool documentation, API schemas, real usage examples
   - Knowledge graphs of tool relationships & constraints

3. **Multi-stage generation pipeline**
   - Stage 1: Generate diverse tool-calling scenarios (tasks requiring tools)
   - Stage 2: Generate API call sequences for each scenario
   - Stage 3: Generate valid parameters & edge cases
   - Stage 4: Generate expected outputs & error handling

4. **Validation at every stage** (this is where most approaches fail)
   - Automated validation: Syntax, API schema compliance, executability
   - Model-driven validation: Use another LLM to spot errors
   - Human validation: Sample-based expert review

5. **Active learning loop**
   - Train initial model on validated data
   - Identify failure modes on held-out test set
   - Generate targeted synthetic data for weak areas
   - Iterate

6. **Fine-tune with high-quality data**
   - Prefer 1000 validated examples over 10,000 noisy ones
   - Use instruction tuning format with clear task descriptions
   - Include reasoning traces (chain-of-thought) for complex tool chains

### For Diffusion Models Specifically

- Pretrain on general API corpus (if starting from scratch)
- Fine-tune with domain-specific API data (use DomainStudio-style approach)
- Add conditional controls (cross-attention on tool schemas)
- Apply hard constraints (ensure outputs are valid API calls via post-processing)
- Validate & filter aggressively (diffusion models can generate invalid syntax)

## 9. References (Key Papers)

1. Quality Matters: Evaluating Synthetic Data for Tool-Using LLMs (arXiv 2409.16341)
2. On Synthetic Data Strategies for Domain-Specific Generative Retrieval (arXiv 2502.17957)
3. Think Less, Label Better: Multi-Stage Domain-Grounded Synthetic Data Generation (arXiv 2509.25736)
4. DataDreamer: A Tool for Synthetic Data Generation and Reproducible LLM Workflows (arXiv 2402.10379, ACL 2024)
5. Towards Active Synthetic Data Generation for Finetuning Language Models (arXiv 2512.00884)
6. DomainStudio: Fine-Tuning Diffusion Models for Domain-Driven Image Generation (arXiv 2306.14153)
7. Source-Free Domain Adaptation with Diffusion-Guided Source Data Generation (arXiv 2402.04929)
8. Diversify, Don't Fine-Tune: Scaling Up Visual Recognition with Synthetic Images (arXiv 2312.02253)
9. Generative Subsurface Flow Modeling With Pretrained Diffusion Model (Geophysical Research Letters, 2025)
10. LLM-Synthetic-Data Repository (GitHub: pengr/LLM-Synthetic-Data) - Comprehensive living bibliography updated to July 2025

## 10. Specific Questions Answered

### Q: "How to get diffusion models to focus on a domain? Pretrain in the domain?"

**A: Three approaches (in order of effectiveness):**

1. **Fine-tuning pretrained models with domain data** (most practical)
   - Use techniques like DomainStudio to maintain diversity while adapting
   - Requires far less data than pretraining from scratch
   - Can leverage general knowledge from base model

2. **Conditional generation with domain classifiers**
   - Add domain-specific conditioning signals (cross-attention, classifier guidance)
   - Training-free approaches via knowledge alignment
   - Most flexible—no retraining needed

3. **Domain-specific pretraining** (most data-intensive)
   - Only viable with large domain corpus (millions of samples)
   - Best for highly specialized domains (e.g., medical imaging, scientific simulations)
   - Continued pretraining (hybrid) often better than from-scratch

### Q: "Diffusion models provide broad distribution but how to focus?"

**A: This is the core tension. Solutions:**

- Narrow via fine-tuning but use regularization to prevent collapse
- Control via conditioning without retraining the full model
- Filter generated samples using domain-specific validators
- Hybrid generation where diffusion creates candidates & discriminator filters
- Accept some breadth as beneficial for generalization (don't over-narrow)

## Conclusion

The state-of-the-art in 2024-2025 for domain-specific synthetic data generation emphasizes:

1. **Quality over quantity** (especially critical for tool calling)
2. **Multi-stage generation & refinement pipelines**
3. **Active learning & iterative improvement**
4. **Domain knowledge integration** (constraints, schemas, knowledge graphs)
5. **Hybrid LLM + diffusion approaches** for best of both worlds
6. **Rigorous validation at every stage**

For tool calling specifically, LLM-based approaches currently outperform diffusion models due to the discrete, symbolic nature of API calls—but diffusion models show promise for exploring parameter spaces & generating diverse edge cases once initial examples are validated.

---

*Research compiled: December 3, 2025*
