# 你以为你会哈希？

标题：So You Think You Can Hash

日期：2024/12/04

作者：Victor Ciura

链接：[https://www.youtube.com/watch?v=lNR_AWs0q9w](https://www.youtube.com/watch?v=lNR_AWs0q9w)

注意：此为 **AI 翻译生成** 的中文转录稿，详细说明请参阅仓库中的 [README](/README.md) 文件。

备注：没细看，感觉内容有点不知所谓。

-------

我们要讨论哈希（hashing），哈希一切。

哦，必讲的幻灯片。这是我过去“造成过一些破坏”的地方。如果你认出其中一些Logo，我很抱歉。还有联系我、关注我的方式等等。就是那些常规的东西。好的。那么，一点背景和动机。哈希，我认为大家都会同意，尤其是如果你走进了这个房间，它是我们使用数据结构进行存储、检索、查询、搜索等等工作的重要组成部分。用于自定义类型的索引，以及我们构建的各种聚合、索引、数据库、查找表等等。所以它是我们日常活动的重要组成部分。哦，来了？好的。那么，我们将尝试探讨我们希望从这些东西、从哈希函数中获得的一些属性。我们寻找哪些保证？一些良好的特性。我们如何定制这些东西？我们如何提高构建此类设施的易用性（ergonomics）？当然，还要保持一切高性能和良好。所以我将提到过去七年，也许更久，现在八年了，在C++委员会中涌现的一些正在进行中的论文和提案。我会提到一大堆。当然，今天演讲的大部分内容是由其中一些研究工作推动的。但我不打算深入那些提案更复杂方面的“雷区”，那些棘手的部分。我确实有所有这些提案的链接，所以你们可以随意浏览查看。如果你过来找我并想讨论具体细节，我会非常感激。也许你脑子里有其中某篇论文的想法。也许你读过它。也许你对其中一些事情有强烈的感受。我很乐意聊聊这些。但我在演讲本身不会重点讨论这些。演讲更可能旨在提高认识并教育更多人了解这些问题，从基础知识到当你扩展规模或为你的自定义数据类型构建此类哈希设施基础设施时可能出现的挑战。

因此，我们寻求构建一个哈希框架，以便轻松尝试不同的哈希算法并进行基准测试。所以我们希望拥有轻松替换哈希算法并进行比较的能力，或者也许稍后更改我们的实现，并将此实现细节与我们数据类型的用户隔离开来。因此，哈希部分不应该泄漏到API设计中，除非我们是在设计一个哈希库，对吧？所以我们将涉及如何处理哈希复杂的聚合用户定义类型，因为我们需要处理这类事情。并且我们将尝试比较其中一些技术。

一些目标。我在摘要里提过这些，但以防你只是被标题吸引进来的。想法是，哈希算法设计者通常是数学家，他们需要关注数学以及如何实现一个好的哈希函数或好的哈希算法的正确性。他们不应该关心你如何消费它。他们应该关心应用领域、数据形状、所能提供的保证以及这些哈希函数所能提供的性能特征。但他们不应该影响你在库或应用程序代码中的API设计。而类型设计者、广大开发者应该专注于如何构建这种基础设施，如何构建这些有弹性的设计，这样他们就不会受特定选择的哈希实现或标准库附带的任何东西的实现细节所驱动。因此，我们需要以某种方式找到这种分离，以便在设计我们的类型和库时不会出现这种抽象泄漏（abstraction leak）。

我们将通过实践这些机制并找出哪些有效、哪些无效，来获得一些实用的见解。我会有很多代码，但我会尽量慢慢地过一遍。没什么复杂的。希望一切总是超级基础。但在任何时候，如果你觉得我讲得太快，或者我可能跳过了某个步骤之类，请在那里打断我，提出问题。我很乐意回去重讲（rehash）。好的。

一些入门知识。大多数编程语言都提供这类容器，但如果你使用的是标准的，或者如果你自己实现的，这并不重要，因为在构建这类查找设施时，你会面临同样的挑战。所以，再次，入门知识。如果这太基础了，在接下来的大约一分钟里，请随意忽略我。哈希函数应该能够生成这些哈希键（hash keys）、哈希码（hash codes），并为我们提供一种索引到我们正在归档的数据集合的方法，并且它应该以高效的方式做到这一点。我们的目标是拥有一种有效分布这些值的方法，以便在需要时能够有效地检索它们。所以，这就是事情应该如何运作的基础。哈希函数的定义域，即所有可能键的集合，通常比输入范围大。因此，我们需要以某种方式找到一种方法将这些值分配到桶（buckets）中，以便在哈希冲突的情况下，我们只需查看一个非常有限的元素集合，因为即使最好的哈希算法也无法保证唯一性。这就是整个想法，对吧？

我们寻求的一些属性：

- **确定性（Determinism）**：你可能会说这是理所当然的，但情况并非总是如此。哈希过程必须是确定性的，意味着对于相同的输入，它应该产生相同的哈希值，对吧？
- **均匀性（Uniformity）**：这很难实现。一个好的哈希函数应该将预期的输入尽可能均匀地映射到输出范围，即陪域（co-domain）上。理论上，它应该有相同的概率命中这些陪域值中的一个。
- **固定大小输出（Fixed-size output）**：通常非常期望函数的输出具有固定大小。这就是当我们说，例如，我们想将这个哈希值编码在一个32位整数中时，对吧？所以我们希望拥有这些...（这里信号似乎中断了）我们在这个上丢失信号了吗？是的。是的，有些...好吧，也许是暂时的。所以我们希望对我们产生的哈希码的大小有一个有限的界限，对吧？我们不希望这个输入...抱歉，这个哈希码与输入值成比例，对吧？它有点像固定大小的摘要（digest）。这带来了挑战，即我们只有有限的空间来编码它。
- **不可逆性（Non-invertible）**：在某些情况下，例如在密码学应用中，我们会希望非常非常难以逆转这些哈希操作。（幻灯片似乎有技术故障）这个似乎有些技术故障。这个也一样吗？没有？好吧。我想我们继续吧。好吧。但并非所有场景都需要这种保证。所以许多这些哈希函数不提供任何密码学保证。这没关系。当然，取决于应用领域。

那么，在我们探索其中一些设计时，我们需要问自己一些问题：

- 我们应该如何组合来自数据成员的哈希码并创建一个好的哈希函数？这将是我们花费最多时间的一个问题。
- 我们如何根据我们列举的所需属性知道我们拥有一个好的哈希函数？
- 如果我们发现我们没有这样一个好的聚合或哈希事物的机制，我们如何达到改进它的地步？
- 好的。我们如何为复杂的聚合类型做到这一点？

好的。因此，我们希望分离这些关注点（separation of concerns）。我会多次强调这一点。我们希望将算法部分与对象如何通过其关键位（salient bits）参与哈希分离开来。好的。

让我们假设我们想将一些用户定义类型存储在哈希映射（hash map）中，因为我们不能总是只存储字符串和，比如说，唯一标识符之类的东西。所以，假设我们想直接在这种查找容器中存储一个客户（customer）结构体之类的，对吧？有时我们会使用这种技巧或捷径，因为它自然符合设计。例如，如果我们有某种数据库条目，或者我们有某种表示模型的唯一字符串，那么很自然地我们会使用这种技巧，而不是使用我们直接的数据结构作为查找键（key）。但在许多情况下，人们实际上只是因为他们不知道如何处理哈希用户定义类型而做这些捷径。希望我们将展示这毕竟不是那么复杂的事情。因此，你不需要总是为了便于存储在哈希容器中而发明人工的唯一键（unique keys）。

那么，如何哈希这样的类型呢？所以，让我们... 你首先看的是标准。我们很快发现标准中有一个标准哈希（`std::hash`）的东西。它接受一个模板参数，即键（key）。它提供了一些保证和一些神秘的哈希能力。它返回 `size_t`，代表哈希码。如果两个键相同，它保证它们生成相同的哈希码。如果两个键不同，它某种程度上保证获得相同哈希码的概率非常非常低。目前就这么多。有趣的是，它为各种有趣的原始类型、字符串和更多标准库的东西提供了一堆特化（specializations）。所以看起来它很方便且开箱即用，对吧？那么，让我们试着弄清楚如何将这个用于我们的客户（customer）类，对吧？假设我们有一个 `hash_code` 函数，它代表我们客户类的聚合哈希值。我们尝试应用这个 `std::hash`，因为它只知道如何处理字符串、整数之类的东西。我们对名字（first name）进行哈希，对姓氏（last name）进行哈希，对年龄（age）进行哈希，对吧？两个字符串和一个整数。然后，我们用它做什么，对吧？我们如何获得整个结构体的聚合哈希值，对吧？我们如何以任何有意义的方式组合这些代码？我们可以为此使用什么算法？什么会是好的策略？

我肯定你们中的许多人现在会举手说，哦，`boost::hash_combine`，对吧？如果你知道这个，你也知道其中一些问题。但我们按部就班来。那么，如果我们想要另一个哈希算法呢？这是我们可能会问自己的另一个问题。在我们写的所有这些标准C++代码中，算法编码在什么地方，对吧？`std::hash` 背后的算法是什么？

那么，让我们先看看如何处理这个 `hash_combine` 的东西。我们想要一个代表整个结构的统一哈希值，对吧？信不信由你，有一些数值技巧我们可以使用，就像 Boost 的 `hash_combine` 那样，但有几种数值技巧。它们中的每一个都更适合于用于我们要组合的部分的哈希算法类型。但有一些技巧可以利用这些数值操作来获得一个好的组合器（combiner）。这是一个这样的例子，对吧？你获取一个当前种子（seed），即当前的摘要（digest），然后你接收一个新值，你神奇地使用某种花哨的常量，你可能会问，那是什么？然后你将新值聚合到现有的种子中。你通过那个魔法数字来累积它。那个魔法数字，它实际上是一个非常有趣的数字。在许多这样的数值操作中，你最终会使用某种无理数的表示。在这个例子中，它是黄金分割比（golden ratio）的倒数（reciprocal）。所以这就是你得到那个看起来奇怪的常量的地方。所以，这个 `hash_combine` 函数有点用，确实。但它足够好吗，对吧？它灵活吗？它能与任何哈希算法一起工作吗？或者它只适用于当前 `std::hash` 里面的东西，对吧？它灵活吗？它允许任何组合吗？它会与 CityHash 或我想在那里使用的任何其他算法一起工作吗？它是否足够强大，能够保证组合这些值会给我带来良好的分布？我们不知道。

那么，让我们看看如何改进这个。另外，在使用这个的过程中，你看到它具有累积性（accumulative nature），对吧？你从一个种子开始，在那里做一些数值转换，然后修改种子，对吧？但出现的问题是，从零开始，这是一个好的起始种子吗？我们应该如何使用它？如果你只是随意使用它，它可能也能工作。但你是否在良好的输入域上测试？你是否彻底验证了所有这些属性？它真的好吗？

问题源于哈希算法隐藏在其中的事实。它隐藏在 `hash_combine` 中。它使用了，在那里它使用了 `std::hash`。所以它本身隐藏了哈希算法。问题在于算法被组合步骤（combine step）污染了。所以我们在这里混淆了两件事。我们使用一种算法对部分进行了哈希（仍然不知道那是什么）。然后，我们必须处理聚合这些哈希码，这是稍微不同的事情。我们不是使用相同的算法来做这个。我们发明了一些处理这些值的新的花哨东西，对吧？使用那些魔法常量等等。所以，我们污染了哈希函数的品质，对吧？我们不能再基于部分对整个做出任何断言。我们对部分进行了一些操作，但我们不能对整个做出任何断言，因为我们弄乱了比特位。我们弄乱了熵（entropy），弄乱了任何这些数学保证。它不再纯粹了。当然，如果我们想用不同的哈希算法进行测试，我们基本上就被锁在那里了，对吧？

我提到这个好几次了，但没问。那么，有谁知道 `std::hash` 背后的算法是什么？这是一个听起来有趣的算法，好吧？是 FNV-1a。不能保证它应该是什么，但大多数实现中碰巧是这个。所以它是一个非常简单，但足够好的哈希算法。信不信由你，这就是全部了。再次，一些魔法数字汤和一些比特操作（bit twiddling），然后，瞧，我们有了一个哈希。对大多数应用来说足够好了。它在任何方面都不是特别出色，但这是一个混合的体验，对吧？如果你想了解更多，可以阅读一下。维基百科上有一个非常详细的页面介绍它。所以它有一些魔法常量，一个质数（prime number），就像你通常处理这类事情那样，对吧？而且，你可以轻松应用这样的函数来获取所有常见类型的哈希码，对吧？你可以看到，我们基本上是在操作字节（bytes），所以你几乎可以对任何原始标量类型（primitive scalar types）做这个。你可以直接把它们塞进去并计算这样一个值。

那么，让我们控制这个，对吧？与其使用 `std::hash`，不如更刻意一些。让我们应用这个函数并做同样的事情。回到做同样的事情，对吧？做哈希码，直接在每个数据成员上应用 FNV-1a，然后，同样的问题又来了，对吧？现在，我们说，哦，现在我们知道它是 FNV-1a 了，对吧？所以也许我们现在可以更聪明一些，因为我们知道算法，所以我们可以更聪明地组合这些东西。不幸的是，这没那么容易，因为你不能只是使用同一种算法来摘要（digest）摘要码（digest codes），对吧？仅仅因为你现在知道实现，并不一定意味着你能更好地组合这些值。也许你可以，但盲目地应用相同的哈希码函数并不能解决问题。所以，我们又在原地踏步了。

我认为，如果我们开始研究更多这些算法，看看它们的结构，就会获得一些见解。我在那里只列出了几个例子。如果我们看看这些，我们会发现它们的数学“疯狂”有一个共同的结构。这个结构是它们都有这三个阶段：初始化阶段（initialized phase）、消费阶段（consume phase）和终结步骤（finalization step）。它们的复杂度可能不同，性能和优化目标也不同。对其中一些，初始化步骤是微不足道的，或者终结步骤是微不足道的。对一些具有复杂状态的算法，初始化步骤成本更高，消费步骤在响应性方面更易于管理。这取决于它们的优化目标，对吧？但它们都有这种三阶段的相同解剖结构，对吧？如果我们看看我们的老朋友 FNV-1a，我们可以很容易地识别出这三个部分：初始化（init）、消费部分（consume part）和终结部分（finalize part）。当然，对这个算法来说，其中两个是微不足道的步骤。初始化和终结几乎什么也不做，除了处理一些魔法数字。消费部分做了所有繁重的工作，但这是一个简单的算法。我提到的其他算法在初始化阶段做了更聪明的事情。

所以，好的。那么我们现在需要做的是重新打包（repackage）我们的算法。我们需要控制这三个步骤。我们将重新打包哈希函数，不再是简单的一个输入-输出的块，而是提供对这些独立阶段的控制，这样我们可以更容易地使用它。所以，初始化（init）将只是构建，写入（write）将以某种方式贡献给这个摘要，而终结（finalize）将只是产生最终的哈希码。对。这样做，我们将不再需要组合步骤（combine step），正如你将看到的。另一个重要的事情是，我们自始至终使用相同的算法，而不是对部分使用一种算法，然后想出一些其他魔法汤来组合部分结果。

核心思想（salient idea）是让应用程序的其他部分来构造（construct）和终结（finalize）哈希算法，而...（技术故障变得很烦人）...专注于复杂数据类型的每一部分如何通过其关键位（salient bits）贡献给整体的哈希。因此，数据类型不再需要关注设置哈希基础设施的机制，而是需要关注“我如何贡献给这个哈希值”。对。当然，现在需要涉及状态（state），因为我们处理的是一个累积过程。这个东西需要有状态。对。

如果我们现在只重新打包我们简单的 FNV-1a：初始状态是我们哈希器（hasher）中的一个成员。我们有一个消费（consume）函数，它现在只更新内部状态，因为我们现在有一个运行状态（running state），而终结（finalization）只是检索状态，使其可用。所以我们实际上什么也没做。我们只是重新打包了它。但现在我们可以独立访问这三个阶段了。所以现在我们可以应用这个东西，并注意到少了点什么。不再需要 `hash_combine` 了。因为我们一步步地累积了这个摘要，最后我们只说“好的，给我最终值”。现在不再需要任何魔法组合了。因为结构是一步步地贡献给这个整体摘要的。所以现在我们可以说，整个东西是纯粹的 FNV-1a。没有其他任何东西，没有其他魔法的 `boost::hash_combine` 或任何其他魔法东西来扰乱函数的纯粹性和品质。

这些阶段的清晰分离使我们能够轻松尝试不同的算法，它们都具有相同类型的统一结构。因此，无需触及数据模型（data model）——我将展示其代码——我们可以轻松交换算法实现，而无需修改数据模型。

好的，那么我们如何处理嵌套的聚合类型呢？因为之前的客户（customer）内部可能只有标量（scalar）的东西，也许一些字符串。假设我们有一个更复杂、更多层级的结构，客户（customer）在其中的某个地方，而我们拥有我们之前刚刚制造的那个 `hash_code` 函数。所以，如果我们再次采用按部分处理的策略，我们会陷入与之前相同的情况，我们对可归约为标量类型的东西做了处理，但当我们聚合一个更复杂的东西时，我们又回到了起点，我们再次需要一个 `hash_combine` 步骤，所以我们再次搞砸了。

那么，让我们修复它。如果我们回到之前那个简单的客户（customer）类，你再次注意到我们有哈希器（hasher）和终结步骤（finalization step），我们将这些东西分开了，这样我们可以处理部分，但我们把它们放在同一个整体的 `hash_code` 函数里，这正是我们现在在上升到聚合所有这些东西的销售（sale）类时给我们带来麻烦的原因，因为我们仍然在 `hash_code` 函数里有这些东西，并且我们将其视为一个单一操作（monolithic operation）：“给我哈希码”，并且哈希器在里面。

所以我们需要做的是，将这些高亮的东西从计算中移除，进行更进一步的分离。我们将把它们提取出来并提升（hoist）为参数（arguments），对吧？所以如果你现在注意到，哈希器（hasher）是一个参数，我稍微将函数名从 `hash_code` 改成了 `hash_append`，因为它不再暗示一个单一的“哈希码我完成了”的操作，它暗示了一个瞬态阶段（transient stage），在这个阶段我有一个哈希码的运行状态（running state），并且我把它变成了一个友元函数（friend function），这样它可以更统一地应用于所有部分，因为我们将在不同层级有更多这样的 `hash_append` 函数——在销售（sale）层级、客户（customer）层级、日期（date）层级等等——所以我们希望在那里有某种统一性。

现在，相同的机制可以重新应用，因为我们不再有一个单一的“给我哈希码”的操作，我们有一个运行着的“我的哈希的当前状态是什么”。所以如果我们现在为这个聚合结构重写，我们有一个 `hash_append` 函数，它在外部接收哈希器对象，然后递归地——不完全是递归——但它会深入到所有层级去做同样的事情，即每个层级的 `hash_append` 机制。销售（sale）的 `hash_append` 又会调用其所有部分的 `hash_append`，如此下去，乌龟塔（turtles all the way down），对吧？所以我们现在以一种非常统一的方式做这个。

看起来所有这些部分现在都贡献给了贯穿整个数据结构的整体状态。但没有人知道是谁在编排这件事，是谁初始化了这个操作，整体的哈希器（hasher）驻留在哪里。当然，一直向下，`hash_append` 最终会到达原始标量类型（primitive scalar types），我们可以为这些东西定义重载（overloads），对吧？这样我们就有了一个统一的方式一路向下。

所以我们可以为所有我们想要的原始类型定义这样一个统一接口。如果我们现在只是从将 FNV-1a 作为参数传递给这个我们传递下去的函数，抽象掉这个细节，我们就可以忽略它碰巧是一个 FNV-1a 实现的事实。在贡献给摘要（digest）的整个机制中，我们没有做任何假设说它是 FNV-1a，对吧？我们只是指示结构的所有成员将其关键位（salient bits）贡献给这个整体状态。你不需要关心它背后是什么，状态如何管理，哈希器实际上在做什么。你只是在告知它你希望如何贡献，对吧？所以我们现在可以轻松地用特定的其他实现替换掉，因为我们不再将哈希算法泄漏到数据类型中了。

当然，我提到过，对于可哈希类型（hashable types），原始的东西如整数和其他标量类型，它们可以直接将字节贡献给摘要，它们不需要做任何花哨的事情。但我们希望有同样类型的统一接口。所以如果我们定义同样类型的函数，即使它们是微不足道的，我们也要包装这个东西，这样它们一路向下看起来都一样，对吧？所以这里的诀窍实际上没那么复杂，因为它们都被分解成子部分，一直到标量，每一步每个类型递归地向下贡献，对吧？在每个步骤，每个类型都有一个 `hash_append` 重载，每个类型只需要关心它自己的数据类型、它自己的结构，对吧？并说明我的哪些部分需要贡献给这个东西，对吧？如果有原始的东西，只需将字节发送给状态（state），对吧？再次强调，它们不再关心这些东西是如何被摘要（digested）的，它们只说“我想贡献，我想贡献这个部分”，对吧？

另外我想提一下，因为有些人在这里做过头了：你只需要贡献类型的关键部分（salient parts），类型中的一切并不都需要成为哈希结果的一部分，对吧？当然，这里存在一些问题，涉及到最终可能出现在你的数据类型中的一些更花哨的东西。例如，我们如何处理作为聚合类型一部分的可选类型（optionals）？在我们的类型中，我们是否需要某种存在指示器（presence indicator）来表示一个可选类型是否被设置？它是否需要参与哈希？如果它存在或不存在，我该如何表示？我能把它当作一个0个或1个元素的向量（vector）吗？所以为了哈希的目的，就假装它是一个集合（collection）。可以是。我们如何处理变体类型（variants）？我们如何表示哪种类型被激活（activated）并需要贡献给整体的哈希值？再次，这些都是更棘手的问题。我很想鼓励大家就此话题进行某种对话，但也许我们留到最后，如果你现在有问题，请随时打断我。

（观众提问）  
是的，请用麦克风好吗？就在前面，或者喊大声点。  
想象你有一个结构体（struct），里面有两个向量（vectors），你可以想象向量的长度总和是一个常数，对吧？如果所有这些向量中的元素都完全相同，那么你有一个结构体，它的第一个向量里有一个元素，第二个向量里有负一个元素（？），另一个结构体在选择的向量（choice vector？）里有两个元素，在第二个向量里有负两个元素，等等。像这样的结构体总是会计算得到相同的哈希函数，或者说对于任何总和为零的输入（ever-sero inputs？）...

好的，这是一个非常好的问题，它与这样一个事实有关：从贡献给整体摘要（digest）的这个角度来看，它无法区分这些贡献来自哪里。它们来自你提到的第一个向量，还是来自第二部分，对吧？你无法再区分了。也许我们需要与处理可辨识联合体（discriminated unions）同样的原理，我们需要以某种方式在编码时表示这一点。但我认为这是特定类型的设计选择，如果这对它的存在以及它如何哈希自身是相关的，那么它就需要在输出中编码这个信息。例如，我灵光一现，它可能只是在其结构顶部编码贡献方式，并说“好的，我从我的结构中贡献这些位，它们来自槽位一（slot one），或者它们来自大小为二的桶（bucket），这些位来自大小为四的桶”，所以你让这种表示具有更多意义，而不仅仅是“我是字节的总和”（sum of my bytes），对吧？因为你想消除歧义（disambiguate），你想说“好的，我想明确指出这些部分来自对象的这个部分”，你提到的第一个向量，对吧？所以你让那个部分...我认为同样的原理适用于合成事物（synthesize things）。我见过这样的情况，你为了等价关系（equivalence relation）而假装贡献东西，例如，即使在你做相等性（equality）表示或序列化（serialization）时，你可以有同样的考虑，同样的讨论，并说“好的，我想清楚地标记这个贡献来自我对象的这个部分”。所以你可以专门编码这个，就像你处理类型中的变体（variant）一样。再次强调，这是你对象的设计选择，如果它关心这些事情。我会非常怀疑我们应该总是尝试做这些区分的主张，因为我认为在大多数情况下，这并不重要。很乐意多聊，因为我觉得你脑子里有具体的场景，我想了解那些。所以在讲座结束后在走廊上找我，因为我想问你一些问题。

我们时间怎么样？我需要快点。一个，这只是一个备注或补充，因为在安全领域（security），我们经常正是需要这种属性。所以如果这对你相关，你可能想看看默克尔树（Merkle trees），这正是你需要的。它就像一个保留结构的层次化哈希（hierarchy or structure preserving hash）。太棒了，太棒了。酷。

那么，既然我们大概弄清楚了如何分解和重新打包这个东西，我如何轻松地将它放入无序集合（unordered set）或映射（map）中呢？这又是一个重新打包的操作。我们只是创建一个泛型哈希包装器（generic hash wrapper），它临时封装了哈希算法。再次强调，我们不关心那里的实现细节，我们只需要在那里有一个函数调用操作符（function operator）。一旦我们重新打包了它，我们就可以直接把它放入另一个集合或映射中，就像你在底部示例中看到的那样。有了这个，我们就可以尝试所有其他各种各样的东西了。我们可以看到 Crash、Spooky、Murmur、CityHash，它们都可以以这种方式重新打包，因为它们都可以分成初始化（init）、消费（consume）、终结（finalize）这三个部分。所以这就是我们可以轻松尝试的地方，并说“好的，我现在想进行基准测试，我有我的设置，我有我的数据收集，我只想改变实现来看看它是否对我处理的输入类型有影响”，对吧？所以尝试变得微不足道。

我在开头提到了一些有趣的论文。我这里有一个集合，大部分是关于处理这类事情的。其中一些现在真的很老了。这些提案都还没有进入标准（C++）。它们都引发了有趣的讨论，但还没有成果出来。我强调了四篇我觉得非常有趣的论文。你可以阅读它们，它们有非常有趣的例子。你甚至可以浏览与它们相关的讨论。它们有多个修订版，例如最后一篇就有多个修订版。所以其中一些试图建立在彼此的工作基础上，并试图解决先前版本中的一些问题，但然后它们又带来了新的想法和新的问题。所以我不一定认为它们是彼此的超级集合（supersets），但它们确实有一些重叠。所以，在某种程度上，我会说，如果你有兴趣了解更多，我不会只挑一篇来看，因为你很快就会发现它们引用了其他东西，然后你就掉进兔子洞，把所有的都读了。这就是为什么我把链接放在这里。

总之，就像我提到的，我不想深入细节。如果你真的很懒，只想让我给你这些论文的摘要的摘要（digest of the digest papers），我的朋友 Dietmar 在这里对所有那些论文有一个非常好的总结。你可以读那个，我在那里放了一个链接。这些是我发现最有趣的四篇。

好的，现在我有一个有趣的题外话。所以我需要回到讲台后面，只是防御性地（in defense）说，因为我知道我在 C++ 会议上，我想花几分钟看看 Rustaceans（Rust 用户）如何处理哈希，看看我们是否能从中学到一些东西，无论是好的还是坏的。再次强调，我不是来向你推销任何 Rust 蛇油（snake oil）的，只是看看他们的标准库，看看我们是否能从中学到什么，因为他们已经在标准中有了这些东西，而我们只是在讨论它们。

好的。在 Rust 中有特征（traits）。有很多特征。特征只是——我只解释你需要了解的关于哈希（hashing）的重要部分——特征只是协议（protocols）、接口（interfaces）、抽象接口（abstract interfaces），随便你怎么称呼它们在你最喜欢的编程语言里。它们有必需的方法（required methods）和可选的方法（optional methods）。我们只处理必需的方法。我们有一个哈希特征（`Hash` trait），它只有一个必需的方法，叫做 `hash`，它接收一个代表状态的哈希器（`Hasher`）。注意在 Rust 中，类型在右边，不在左边，所以不要搞混了。而 `where` 子句只是编写类型和特征边界（trait bounds）的更漂亮的方式。好的。所以有这个 `append` 方法（在 `Hasher` trait 中）。如果你仔细看 Rust 标准库，你会很快注意到同样的想法，这并非偶然——我碰巧做了这个类比——他们从我们的实验中学习，现在他们在运行自己的。有相同的附加函数（append function）概念。它被称为 `hash`（在 `Hash` trait 中）。如果我们看看如何为 `Customer` 实现 `Hash` trait，它又会是和我们之前看到的相同想法：每个成员都贡献给这个哈希状态（`Hasher` state）。所以 `Hash` trait 中的这个 `hash` 函数就等同于我们之前的 `hash_append`，我们之前的消费步骤（consume step），对吧？当然，有方便的东西。在 Rust 中，你可以用宏（macros）做很多简写和语法糖（syntactic sugar），它们与你见过的其他宏非常不同，但只是让你知道，有方法来自动合成这些东西，所以如果你不需要自定义行为，你写的样板代码（boilerplate）甚至更少。所以你可以直接放一个 `#[derive(Hash)]`，如果它的所有部分都是可哈希的（`Hash`），那么这个类型就自动变成可哈希的（`Hash`），对吧？所以再次，这是一个传递性（transitive）的事情：如果所有部分都是 `Hash`，整体就是 `Hash`。这里有一些关于相等性（equality）以及这与哈希如何相关的微妙之处，但除非有人真的好奇并且乐意讨论这些需要了解 Rust 中 `Eq` trait 的知识，否则我不会深入这些细节。

好的。这个特征（`Hash` trait）为几乎所有标准类型提供了实现。那里有一个完整列表的链接。我这里只展示两个字符串类型的例子。顺便说一下，Rust 中有很多字符串类型。你可以看到在这些例子中，它们可以相互依赖。例如，`String` 中的 `hash`（即 `Hash::hash`）实现回退（falls back）到字符串切片（`str`）中的 `hash` 实现（即 `Hash::hash`），`str` 是 Rust 中的字符串切片（string slice）。

我们有一个 `Hasher` trait，它带来了一个我们可以实现的实际的哈希器对象（hasher object）。顺便说一下，Rust 没有真正的重载支持（proper overloading support），这就是为什么你看到那些 `write_u8`、`write_i32` 等等，它们需要被实际调用不同的名字。但你看到的是相同类型的机制：你有这些贡献函数，这些为原始类型、所有标准库类型和用户定义类型准备的附加函数（append functions），它们被分解为这些类型的东西，对吧？如果你想自动化，你可以用那些宏来自动化，但如果你不想，你实际上可以手动编写这些函数。

再次注意，我们在这些地方都看不到任何关于所涉及的哈希算法的细节，对吧？我们只看到类型如何将其关键位（salient bits）贡献给哈希的整体贡献。我们看不到东西是如何被哈希的。我们甚至可以注意到这个操作基础设施的三个阶段：我们看到初始化阶段（init stage），我们看到消费阶段（consume stage），我们看到终结阶段（finalization stage），它实际上被称为 `finish`。

这里有一个非常简单的默认哈希器（`DefaultHasher`）的例子，只是向里面添加一些随机类型、字符串之类的东西，然后从中获取整体值。再次强调，它有一个运行状态（running state），中间阶段只是贡献给这个运行状态。

再次强调，这里有一些脆弱的部分（brittle parts）。所有这些都容易受到顺序（order）的影响。还有另一件事我可能没提过，也许与之前提到的关于对象不同部分贡献给整体哈希的问题略有相关。同样的事情也适用于顺序：你需要文明地强制一个可预测的顺序，规定你如何将这些东西序列化（serialize）进整体哈希值，对吧？

好的。这个 `Hasher` trait 有几个实现。我们有一堆哈希器。有一个 `RandomState`，它是标准库中哈希映射（`HashMap`）和其他可哈希类型的默认哈希器（default hasher）。有一个 `DefaultHasher`，它的内部算法没有指定，但它实际上是一个 `RandomState`。还有一个通用的 SipHasher，它在很多场景下都相当不错。里面还有一些其他东西。所以有多个实现。当然，人们会在需要时实现自己的哈希器，当他们有特定需求时，或者当他们想要一些不在标准库里的东西时。所有这些都在标准库里，对吧？

在 Rust 中，很多模式都是围绕构建器（builder）构建的。所以他们实现了类似构建器的东西，但如果你在想 Java 构建器，它们不是那样的。它是一种不同的构建器模式（builder pattern）。所以有一个特定的 `BuildHasher`，再次是为了强有力地带来这种分离：在我们如何创建哈希器对象和我们如何将贡献给哈希的操作委托给底层类型或集合或聚合类型或我们拥有的任何东西之间，有一个非常清晰的区分。对于 `BuildHasher` 的每个实例，创建的哈希器应该是相同的，对吧？并且具有相同的输出。

所以如果我们在这里看到，假设我们实例化一个 `RandomState` 哈希器，我们可以请求 `build_hasher`，我们可以看到它们有相同的可预测结果。假设我们想要构建一个花哨的哈希器（`MyFancyHasher`），我们需要做的就是实现那个 `Hasher` trait，它有两个必需的方法：`write` 方法（即 `append`，是进行摘要（digest）的函数，贡献哈希算法本身）和 `finish` 函数（它只是获取最终值）。这就是你使用它的方式。没有比这更核心的了。

再次，我认为我们可以清楚地看到与之前我们在 C++ 中看到的东西的相似之处。如果我们想为聚合类型做这个，我们同样可以做这种递归的事情：我们在每一步都有 `hash` 函数（在 `Hash` trait 中），它们附加东西（通过调用 `Hasher` 的方法）。所以看起来像是对每个结构的深度遍历（deep traversal），在每个层级调用这个 `hash` 函数（即 `Hash::hash`），每个层级都知道如何将其关键位贡献给整体状态，但它不关心那个状态是什么，它只是说“我想以这种方式贡献”，对象的这个部分需要被贡献，不关心它在数值上如何处理。

如果你想使用标准哈希映射（`HashMap`）并将那个聚合的 `Sale` 对象放进去，看起来就是这样。我使用了派生宏（`#[derive(Hash)]`），只是因为我们已经看到它如何工作。如果你想构建一些花哨的哈希器，你只需要说“好的，我将使用 `BuildHasher`，我将把一个 `SipHasher` 塞进去，现在我可以把它和我的哈希映射一起使用了”。实际上，这就是所有的代码。容易。

再次强调，这并非旨在作为 Rust 如何做事的入门教程，而是为了展示其与我们之前内容的相似性（parallels），以展示他们在标准中采用了同样的设计语言：分离了哈希器（`Hasher`）与需要分布在类型内部的附加操作（`Hash::hash`）之间的关注点。因此，渗透到类型中的侵入性部分（intrusive bit）——我们设计的可哈希类型——与算法本身的数值计算关注点分离开了。

所以这就是事情的结论。这允许：

- **轻松尝试和基准测试（Easy experimenting and benchmarking）**：你可以轻松地交换东西，如果你没有在你的类型中到处泄漏这个实现细节。
- **哈希复杂数据类型（Hash complex data types）**：所以希望现在你看过一些例子后，不会仅仅因为方便就把一个字符串当作哈希键（hash key）塞进去。
- **苹果对苹果的比较（Compare apples to apples）**：我们现在可以真正地进行比较了，因为我们不再需要为了尝试一个新算法而改变整个世界和所有的数据结构，对吧？我们看到我们轻松地切换了实现，我们有了适当的重新打包（repackaging）机制，而且这不是幻灯片演示（slideware）——整个东西能放在幻灯片上，因为它就是那么简单，没有任何隐藏的东西，对吧？

再次回到最初的目标：

- **哈希算法设计者（Hash algorithm designers）** 需要关注数值计算（numerical computations）、它们提供的保证（guarantees）以及它们强制执行的属性（properties）。
- **开发者（Developers）** 在设计我们的类型时，不应该泄漏这些尝试和实现细节，我们应该能够在我们想要的时候自由地改变事物，而不必对我们的类型进行大手术（major surgery）。所以我们只需要关心我们对象的哪些部分是相关的（relevant）或者不相关（not relevant），以及我们如何需要表示这些部分的哪些属性（properties）——用于相等性目的（equality）、序列化（serialization）、哈希（hashing）、各种意图（intents）。但我们需要关心的是我们如何内省（introspect）我们的类型，而不是它们如何摘要（digest）成某个数值（numerical value）。

所以这些就是见解。所以我认为**分离（separation）** 是最重要的一点。其他一切都只是机制：类型和各种重新打包以及语法糖（syntactic sugar）在某些情况下。主要的收获（takeaway）是要有这种分离，不要混淆数值计算（numerical computation）和类型设计（type design）的关注点。这应该是不同的事情。

所以我们有几分钟时间进行正式提问（on the record），更乐意有更多时间在走廊进行非正式聊天（off the record chat）。没有？好的。那么我们可以结束了。我想和你们中的一些人聊聊，因为我听到了一些有趣的事情。所以我想在走廊上找到你们，了解一下你们是怎么做的。好的。谢谢大家。
