# Bidirectional Decoding for Neural Machine Translation

This repository is built upon the [OpenNMT-py](https://github.com/OpenNMT/OpenNMT-py) code. The basic usage of this repository please go to check its document.

The intuition of this project is that  because of the property of the autoregressive decoding process of the sequential decoder, it normally translate in one direction. In this way, we think this kind of model have not make enough usage of bidirectional information of target language. So we proposed two ways to explore this kind of bidiretional information.

#### Multi-task Learning

The first way we explore is Multi-task learning (MTL) way. In this method, we take forward and backward decoding as two tasks. 

![](https://ws4.sinaimg.cn/large/0069RVTdgy1fv5npyswd8j31dy0hqdk0.jpg)

And later we jointly train them with sharing some components. Here, we share same encoder defaultly. We mainly share three components: attention, embedding, and generator.

Then we can try to share single component or multiple component.  Such as:

![](https://ws4.sinaimg.cn/large/0069RVTdgy1fv5nvf895wj31960ms0yh.jpg)

Or share multiple:

![](https://ws3.sinaimg.cn/large/0069RVTdgy1fv5nwv7rvrj31100eejue.jpg)

In the training phase, we assume the shared component learned backward information. So in the test phase, we throw the backward decoding component except shared componets, and predict target with forward decoding.

Result show this model get improvement on WMT DE-EN task (on the full data we get +0.98 near 1 BLEU score improvement than base model) and ZH-EN task (only test on new commentary data because of limited resource, with +0.95 BLEU score improvement).

#### Regularization

This idea is quite simple. We enforce the forward and backward decoding RNN hidden states in same time step to close each other by regularization.

![](https://ws2.sinaimg.cn/large/0069RVTdgy1fv5oaybnk7j30ri0cw414.jpg)

Regulatization here can be various. We use two ways here. First, we just use L2 regularization directly. But this is too strict. Second, to add more flexibilty, we add two linear layer to both hidden states before do L2 regularization.

## Quickstart

You can enable above train options as below:

- `-share_atten:` Expecify sharing attention component.
- `-share_embed:` Expecify sharing word embedding component.
- `-share_gen:` Expecify sharing generator component.
- `-l2_reg:` Expecify L2 regularization, you choose between three options. `none`,`direct`, and `affine`.