# Sentiment Analysis

Given a user voice input (transcribed via our STT pipeline), we want to run Sentiment Analysis to show the user robot faces on the eink screen matching the mood of the current conversation.

## Implementation Status

**Sentiment Analysis Module** ✅ Complete

Created `MoodBot.SentimentAnalysis` GenServer that:

- Loads German BERT sentiment model via Bumblebee
- Maps sentiment to MoodBot's 5 moods: happy, affirmation, skeptic, surprised, crying
- Provides `analyze(text)` API
- Integrated into application supervision tree
- Added IEx helper: `analyze_sentiment("text")`

## Technical Solution

### Model Architecture

**Model**: `ChrisLalk/German-Emotions`

- German emotion classification (28 emotion categories)
- Based on `xlm-roberta-base` (278M parameters)
- Trained on German GoEmotions dataset
- Built-in `tokenizer.json` (no split loading needed)
- Apache 2.0 license

**Emotion Categories (28)**:
admiration, amusement, anger, annoyance, approval, caring, confusion, curiosity, desire, disappointment, disapproval, disgust, embarrassment, excitement, fear, gratitude, grief, joy, love, nervousness, optimism, pride, realization, relief, remorse, sadness, surprise, neutral

### Evolution: From Sentiment to Emotion Classification

**Initial Approach**: Sentiment analysis (positive/negative/neutral)

- ❌ Could not reliably detect confusion or skepticism
- ❌ "Hä?" → affirmation (wrong)
- ❌ "Das verstehe ich nicht" → crying (wrong)

**Solution**: Switch to emotion classification model

- ✅ 28 granular emotions including confusion, surprise, annoyance
- ✅ Direct mapping from emotions to MoodBot sentiments
- ✅ Self-contained tokenizer (simpler architecture)

### Emotion to Sentiment Mapping

Maps 28 GoEmotions to 5 MoodBot sentiments.

## References

- [How to Do Sentiment Analysis With Large Language Models](https://blog.jetbrains.com/pycharm/2024/12/how-to-do-sentiment-analysis-with-large-language-models/)
- [Sentiment analysis using BERT models](https://medium.com/@alexrodriguesj/sentiment-analysis-with-bert-a-comprehensive-guide-6d4d091eb6bb)
- [ChrisLalk/German-Emotions Model](https://huggingface.co/ChrisLalk/German-Emotions)
- [GoEmotions Dataset](https://github.com/google-research/google-research/tree/master/goemotions)
- [Bumblebee Examples - Text Classification](https://hexdocs.pm/bumblebee/examples.html#text-classification)
- [XLM-RoBERTa Base Model](https://huggingface.co/FacebookAI/xlm-roberta-base)
