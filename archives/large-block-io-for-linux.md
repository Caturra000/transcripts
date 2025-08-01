# Linux 的大页块 I/O

标题：Large Block I/O for Linux

日期：2023/10/05

作者：Hannes Reinecke

链接：[https://www.youtube.com/watch?v=HfRhDLbxstk](https://www.youtube.com/watch?v=HfRhDLbxstk)

注意：此为 **AI 翻译生成** 的中文转录稿，详细说明请参阅仓库中的 [README](/README.md) 文件。

-------

大家好，我叫 Hannes Reinecke（汉内斯·赖内克）。你们有些人可能认识我，有些人不认识。我在 SUSE 工作，正如你们在那里看到的。嗯，差不多有，呃，大约 20 年了。我参与 Linux 的时间甚至比这还要长。所以，我刚开始接触的第一个 Linux 版本，我想是 1.15 或 1.05 之类的，那是很久很久以前的事了，真的很古老了。总之，从那时起，我就一直活跃在 Linux 相关的各种事务中。

最近我主要参与存储领域，特别是 NVMe。而现在这个，嗯，其实是我的一个个人项目，它终于实现了。那就是，对大页面的追求。

那么，它是什么？我们为什么要做它？当你做 I/O 时，I/O 不可避免地是以更大的块（称为块）来完成的。这些块目前受到 Linux 内核硬件页大小的限制，在 x86 机器上通常是 4K。而且，各种驱动程序和子系统也隐式地假定了这个页大小限制。然而，这并非世界末日。有些系统和/或应用程序实际上可能受益于更大的页面。有些特定的数据库，它们真的希望以 16K 的增量进行通信，因为数据库内部就是这样组织的。此外，如果我们能迁移到更大的页面、更大的尺寸、更大的块大小，一些硬件也会真正受益，因为这样驱动器内部的开销就不会那么大。不会那么重。整个驱动器会变得，嗯，更高效且更便宜。

那么，我们为什么会有这种限制呢？我的意思是，我们不能直接说，写这个数据，开始吧？嗯，是的，某种程度上可以。问题在于你不能简单地做一个原子的 I/O。没有单一的汇编指令来做“对这些字节进行 I/O”。你总是需要几条指令来设置 I/O、传输数据、取回结果等等。这显然总是会增加你做的每一次 I/O 的延迟。所以，你要做的是尽量减少 I/O 的数量，即实际的 I/O 次数，而不是 I/O 的大小，而是 I/O 的次数。然后，归根结底，问题是，多少 I/O 是最好的比例？我应该传输多少数据？我在这里应该做什么？

在早期，对此进行过相当多的实验。如果在座的有熟悉大型机的，大型机的驱动器仍然有可变块大小的概念，我觉得这非常有趣。所以，你必须在每次操作时决定，对吧，这里的块大小应该是什么？有趣。而且过去进行了大量的实验。当然，像往常一样，伯克利的研究人员最终发现，嗯，512（字节）在存储的数据量（通常非常小）和迁移到更大块所产生开销之间提供了一个很好的比例。但是，这又是 20 年前的事了，但我们一直坚持使用它，并且目前仍然保持这种方式。好的。这就是 I/O。

现在转到页大小。我为什么要谈论页大小等等？

事情是这样的，CPU 架构有一个内存管理单元（MMU），它有一些硬件辅助功能，允许你判断一个给定的内存区域是否是脏的（dirty）。也就是说，需要从磁盘重新读取以获取实际内容的地方。所以，这实际上是硬件辅助的。既然是硬件辅助的，它只能在特定的大小下操作。所以你不能随意选择一个大小，你能选择的大小实际上是由硬件决定的。比如说 x86，你可以选择 4K，2M（大页），我想下一个增量是 2G（巨大页）。就是这样。中间没有其他选择。对于像 PowerPC 或 ARM 这样的其他架构，你有更多的灵活性。比如仍然有一些 Power 系统甚至 ARM 系统使用 16K 页大小。但这仅仅是因为硬件支持它。在 x86 上你做不到。

因此，对于 Linux，我们有一个页大小的编译时设置，它告诉编译器和整个源代码，好了，页大小现在是那个值。由于我们希望与其他架构兼容，这里通用的设置基本上是 4K。我的意思是，对于 SUSE 肯定是这样。我想对于 RHEL 也一样，所以这基本上是我们通用的设置。

但尽管如此，页大小通常意味着，嗯，那是内存管理工作的单位。

所以，现在内存管理是以页大小的增量来工作的。但正如我已经提到的，嗯，我们需要或可能需要将数据从磁盘刷新到内存，以及从内存刷新到磁盘。做这件事的东西叫做页缓存（page cache），向 Willy<del>（指 Linus Torvalds）</del>致敬。所以，那就是缓冲 I/O（buffered I/O），因为它，嗯，我们不是直接写入设备，而是在页缓存中缓冲 I/O。页缓存也是在内存页上工作的。所以，猜猜看？确实，它也是在 4K 页的增量上工作的。所以，当你处理内存页时，有一个硬件设置会告诉你，嗯，这个页是脏的，需要刷新。这会触发 I/O 进行刷新，基本上是将页内容读回内存管理单元。这通常是在页大小的增量上完成的。你可以传输多个页，但显然所有这些页都必须被标记为脏的，以便其背后的硬件逻辑可以工作。

因此，如果我们有比页更大的单元，那么我们需要将它们视为一个单一单元。这在 Linux 中被称为 folio（大页结构）。这就是，哦，我还没讲到那里。所以，稍后再回来说 folio。

然后，我们有一个页缓存告诉块层（block layer），嗯，我想做 I/O。正如已经提到的，我们有两种类型。那就是缓冲 I/O 和直接 I/O（direct I/O）。对于直接 I/O，这很简单。这基本上是用户空间告诉我们，现在传输这个数据。好的。然后你就做了。所以你真的没什么可做的，因为用户空间已经告诉了你 I/O 应该如何布局。对于缓冲 I/O，情况就不同了，因为那是来自文件系统。文件系统通常只关心数据量。它并不真正关心你内部需要如何组织你的数据。它真的不在乎。

为此，实际上有几种接口可以用来做 I/O。主要的或原始的一种叫做 buffer heads（缓冲区头）。然后有一个后继者或底层结构叫做 struct bio（块 I/O 结构）。还有一个叫做 IOMAP（I/O 映射）的东西。再次，回头再说这个。

但为了做到这一点，以便我们能传输更大的块，我们需要将页缓存转换为 folio。现在它来了。我一直等着这张幻灯片。我一听到这个 folio 的东西，我就说，哦，我需要一张带第一对开本（folio）的幻灯片。对吧。我想，好吧。总之，他（指 Matthew Wilcox）得到了它。哦，太棒了。至少有一个。很好。好的。

所以 folio。Folio 是，嗯，基本上是一组页面的通用结构。因为碰巧，我们不仅有普通页。内存管理也知道其他类型。有一种叫做复合页（compound pages）的东西，它本质上是一个页的数组。还有一种叫做大页（huge pages）的东西，这是几年前的一个改进。最初，它是一个单独的文件系统。然后它变成了更灵活的东西，叫做透明大页（Transparent Huge Pages, THP）。你们中的一些人可能听说过或在 LWN 上看到过。所以，它们每一种都有自己独特的工作方式，这使得事情相当奇怪，因为它们都可以通过一个 `struct page` 来寻址。所以如果你有一个 `struct page`，你真的必须知道，它是一个 `struct page` 还是别的什么东西？所以，我们在尝试将页面传输到驱动器时遇到了一些非常有趣的问题。比如 `sendpage` 这个调用，因为它告诉我们，嗯，这真的是一个页面还是我们需要做点别的？

因此，Matthew Wilcox 发明了一个叫做 folio 的结构，它基本上只是所有这些不同事物的一个上层类型。所以，所有这些不同的类型都可以通过一个 `struct folio` 来寻址。在我们这里的案例中，重要的一点是 folio 可以比一个页面更大，这很好。因为如果我们想传输更大的块，这正是我们所需要的，因为那样我们就可以用一个 folio 来标识这些大块中的一个。那会奏效。

有了这个，理论上，我们就可以做大块 I/O 了。然而，这将要求我们，嗯，至少转换页缓存，但更可能的是甚至要将内存管理转换为使用 folio。这是 Matthew Wilcox 在 2020 年首次提出的，并且从那时起一直是 Linux 存储和文件系统会议（Linux Storage and Filesystem conference, LSF）的一个热门话题。正如你可以想象的，它引发了大量有争议的讨论。在某个时候，甚至有人完全拒绝合并它，因为“你为什么需要那个？”嗯，是的，我们需要。而且这是一项持续进行的工作。所以，这只是一个简单的计数器，统计了 `struct page` 的调用次数和 `struct folio` 的实例数量。正如你所看到的，嗯，我们还有很长的路要走。所以这是正在进行的工作。我们最终会达到目标，但我们肯定还没到那一步。

所以，缓冲 I/O。我们做什么？我们怎么做缓冲 I/O？现在这个，你们有些人可能知道，那是 Linux 存储栈的图，如你所见。真正令人沮丧的是，我们只处理右上角那个小小的灰色矩形。所以，那就是我们关注的区域。所有剩余的东西都不关我们的事。Buffer heads。Buffer heads 是从 0.01 版（即 Linux 的第一次发布）就存在的原始结构。它本质上是一个扇区（sector）、一个磁盘扇区的表示。它是 512 字节。假定是 512 字节。它链接到一个页（page），并且有内部缓存，即臭名昭著的缓冲缓存（buffer cache），它避免了每次访问 buffer heads 本身时都要做 I/O。实际上，大多数文件系统仍在使用它们。还有一个用于块设备的伪文件系统（pseudo file system），它也使用 buffer heads。而页缓存本身是在后来才实现的，因为，嗯，buffer heads 做了它们自己的缓冲。

只是为了好玩，这是 buffer heads 的实际结构。所以，正如你所看到的，是的，呃，存储它可真够呛。真正的问题是，我们需要所有这些吗？还是我们不能有更简单的东西？这就是最终演变成 bio 或基本 I/O 结构（basic I/O structure）的原因。这是 Jens Axboe 在 2.5 内核时发明的，基本上是设备驱动程序本身的基本 I/O 结构。所以这允许你做向量化 I/O（vectorized I/O）。意思是你可以将一个页的数组附加到一个单独的 bio 上。并且你可以根据需要将 bio 路由和重新路由到设备。DeviceMapper 就是一个例子，因为它正是这样做的，重新路由、重新格式化 bios 来做它想做的任何事情。RAID 或 LVM 之类的，随你怎么说。这实际上是块层的主要结构。

如今，buffer heads 是在 `struct bio` 之上实现的。所以 buffer heads 会被转换成一个 bio，然后这个 bio 会被发送出去执行实际的 I/O。而且 bio 本身也被相当多的文件系统使用。比如 AFS，还有其他一些文件系统，这样它们就不需要（依赖 buffer heads）了。那些文件系统不使用 buffer heads，而是直接使用 bio。

然后是 IOMAP。正如我所说，哦，Christoph Hellwig 要疯了。他就是会做这种事的人。他不在场。我们能不录这个吗？抱歉。他受够了所有这些用于 I/O 的各种结构和结构。于是发明了自己的东西叫做 IOMAP。这是，嗯，现代的接口，谢天谢地，它已经基于 folio 操作了。因此，这基本上消除了所有中间结构。它只是提供了一种方式，让文件系统可以告诉块层 I/O 应该如何映射。然后由块层来负责正确地映射和布局它。一些文件系统已经被转换了。它显然有直接回调到页缓存的钩子，以便与页缓存协同工作。一些文件系统已经被转换了。最著名的是 XFS、Btrfs 和 ZoneFS。如果有人知道的话。所以对于这些，显然不需要做任何事情。但是文档方面。嗯。肯定有一些。只是很难找到，而且不太准确。不准确是因为那个接口一直在变化。我的意思是，它正处于积极开发中。所以每个新版本，你都会发现新特性，这些特性并没有很好地被记录下来。

那么，我们真正需要做什么才能实现大块传输呢？这只是为了好玩。我只是谷歌了一下“大块”（large block），然后说，是的，是一个面积超过 500 平方米的区域。不是我们想要的。总之。在存储社区有一个长期存在的趋势，那就是 buffer heads 必须消亡（buffer heads must die）。理由是它是一个古老的结构，确实是一个遗留接口，每个人都应该转换到 `struct bio` 或 IOMAP。然后是这句引述，我想是周一或周五的。所以，你可以自己读一下。我不确定我是否能读出来而不违反任何行为准则（code of conduct）。所以也许这个方向不是我们应该追求的。不是如果我们想，想让 Linux 合并那个代码的话。

那么我们该怎么做？所以，嗯，转换到 folio 很好，但真的只影响页缓存和内存管理子系统，并不彻底。所以我们需要在那里做更多工作。问题是 buffer heads 实际上假定 I/O 将在比页大小更小的实例或增量上完成。嗯。我们现在的情况正好相反。我们现在有比标准页更大的增量。所以有几条路可以走。一是转换到 IOMAP。那么显然我们可以直接关掉它。就是不要用它，把所有使用它的东西编译掉，或者尝试更新东西。所以转换到 IOMAP。在理想世界里，这正是我们想做的，因为 IOMAP 是现代接口，而且它实际上是一个非常不错的接口。我是说，还是 Christoph Hellwig。他确实有好的想法和可行的想法。只是，他也有复杂的想法。

所以一些文件系统已经被转换了。所以在理想世界里，我们会把所有文件系统都转换过去。所以如果有人关注过内核峰会（Colonel Summit应为 Kernel Summit）邮件列表上关于下一个维护者峰会的讨论，那里有一个非常长且活跃的讨论，关于我们应该为遗留文件系统做什么，因为这些是遗留文件系统。问题在于，嗯，没有太多活跃的维护者，因为如果曾经有过的话，他（维护者）早就离开了（原文有性别代词，按演讲者要求，将在录音中插入正确的性别形式）。当然，这些文件系统的文档也很难找到，如果它曾经存在过的话。大多数遗留的，特别是那些古老的遗留文件系统，实际上是靠查看它们自身（的代码）来逆向工程的，完全不知道为什么那些东西在那里。那么你怎么去转换这些文件系统呢？这真的是一件很难的事情。当然，你需要有关于 IOMAP 的适当文档，以便让其他不太熟悉 IOMAP 的开发人员能够实际去做转换。所以，嗯，可能这不是我们能够或应该走的路。

当然我们也可以直接说，好吧，只要有 buffer head，就把它编译掉。有一个补丁集，又是 Christoph Hellwig 的，他做的就是这件事。所以，你可以直接删除所有这些东西，因为，然后很简单地，buffer heads 就不再被使用了。而且没有讨论的必要。这个补丁实际上在 6.5 内核合并了。所以从 6.5 开始，你可以，嗯，你可以实际上关掉它。但如果你把所有使用 buffer heads 的文件系统都编译掉，buffer heads 就会被隐式地关掉。所以，嗯，这有点奇怪的接口，但是的，它是向后兼容的。只是，不仅仅是这样，真的很难达到（关掉它的状态）。有趣的是，一些实际上常用到的文件系统，像 FAT 或 ext3，然后就不能工作了，因为它们想被编译进去。因为它们还没有被转换。

当然，总有可能去更新 buffer heads。这实际上是 Joseph Bacic 在上一届温哥华 LSF（Linux Storage and Filesystem conference）上建议的方向。所以，嗯，你可以直接转换整个东西，转换到 folio，然后看看能否摆脱 I/O 需要小于页大小的假设，而让它也能大于页大小。

所以，嗯，它可能相当简单，因为在理想世界里，它已经编码成那样，一切都能工作。或者它可能是一个彻底的噩梦，这个“I/O 总是小于页大小”的假设基本上隐含在代码的各个角落。你将不得不对所有东西进行一次全面审计。所以，最初当我听说这个时，我说，嗯，这不是我想走的方向。当然，还有那些坐在家里（sit-home catering应为旁观者）能看到 buffer heads 等等的人。

所以那天晚些时候，我在看过代码后坐在酒吧里说，哦，天哪，这完全是个噩梦。到底要人怎么去转换它？我们到底为什么还要 buffer heads？我向邻座的人抱怨着。结果后来发现那人实际上是 Andrew Morton，他说，嗯，在我写它的那个年代它相当好。而且它现在还在工作，不是吗？所以，嗯，但谢天谢地，没有什么是喝一杯好酒解决不了的。所以，是的。但话又说回来，这真的让我重新考虑，也许 Joseph 终究是对的。

但是如果你要更新 buffer heads，你就会陷入所有这些你早先根本不想去想的肮脏细节。比如有一个 `void` 指针附加到 bio（bar应为bio）和 `struct page`，嗯，它是一个 `void` 指针。如果使用 buffer heads，它就指向 buffer head。如果使用 IOMAP，它就指向 IOMAP 结构。所以，嗯。然后你发现你实际上运行在页缓存中，意味着这个页被访问这个完全相同页的所有人共享。你是与 buffer heads 对话还是与 IOMAP 对话，这真的有很大的区别。嗯。所以，基本上，这意味着该页或 folio 只能与 buffer heads 一起工作，或者与 IOMAP 一起工作。这对于块设备来说是个问题，因为，嗯，碰巧的是，足够令人惊讶，每个文件系统都运行在一个块设备之上。嗯。如果那个块设备在使用 buffer heads，嗯，文件系统最好也使用 buffer heads。否则，你可能会得到有趣的结果，比如非常漂亮的内核崩溃。嗯。所以，混合搭配（mix and match）的方法需要仔细考虑。

另一个问题是，嗯，UEFI 显然需要一个 FAT 文件系统（原文是 UFI 和 FUT，应为 UEFI 和 FAT）。所以，如果你想关掉 buffer heads，你就不会有 FAT 文件系统。所以启动 UEFI 机器将非常棘手。当然，工作量（webview应为workload）也会很困难。因为你需要找出所有对页大小或对页大小的隐式依赖。比如在枚举页时加一（increment by one）。嗯。

那么，再说一次，我们为什么要做这个？真的值得吗？嗯，我认为值得。但这只是我的看法。所以，我确切知道的一件事是，数据集、数据库真的希望做很多事。所以那肯定会从中受益。希望是我们能获得更高效的 I/O。因为在大多数情况下，文件系统已经会提交更大的 I/O。我是说，Btrfs 费了很大劲来确保总是发送大的 I/O。XFS 也类似。当然，我们也会让驱动器供应商高兴。因为他们制造的驱动器可以更高效或更便宜。

那么，我做了什么吗？还是只是空谈？嗯，我一直在愉快地编码，基本上上周就完成了我的补丁集作为奖励任务。突然，Luis Chamberlain 冒了出来并发送了一个补丁集。哦，这是转换所有东西到大块的补丁集。哦，非常感谢你。你本可以跟我谈谈的。所以，正如我所说，我不为三星工作（原文something应为Samsung）。我和他们的工作毫无关系。而且我在这里展示的完全是我自己的工作，不是别人的。所以，我当然会和 Luis 以及他的同事谈谈，把我们双方的方法结合起来，形成一个联合补丁集。但是，是的，开源不是很棒吗？就在你以为你完成的时候，别人做了完全相同的事，而且比你更快。嗯，好吧。事情就是这样。

所以，不管怎样。我在那里做了什么？所以，我发现如果我们将 buffer heads 从假定它附加到一个页面改为假定它附加到一个 folio，所有底层概念仍然可以工作。那么，在 buffer heads 上的 I/O 仍然会小于附加的单位，即 folio。而且我们可以保留所有 buffer head 的记账（accounting）等等，因为总体规则不会改变。所以，同样地，该页或在种情况下的 folio 仍然会有一个指向 buffer head 的指针，一个指向 buffer head 的单一指针。这将使对 buffer head 或页缓存的更改保持在最低限度。但是然后你在转换时必须遵守某些特定的准则。

问题是，你突然有了不同的单位，需要仔细审视。即，内存管理，所有基于页的东西，内存管理处理的所有东西，它仍然在 4K 或页大小的增量上运行。Buffer head，缓冲缓存（buffer cache）将在 folio 上运行，这些 folio 的大小取决于 folio 被分配时的大小。而且 buffer heads 本身也在 folio 上工作。所以，这很好。

所以 buffer heads 可以做 I/O。但 buffer heads 实际上并不做 I/O。Buffer heads，正如我刚才说的，是位于块层之上，在 `struct bio` 之上。那么它们怎么办？嗯，这就是事情变得非常棘手的地方。因为块层工作在 512 字节的增量上，按块大小（block size），句号（full stop）。那是块层的逻辑块大小（logical block size）。而且实际上没有办法改变它。它被内建在每个地方，并且不，你不想改变它。谢天谢地，做 I/O 的不是它（指逻辑块大小的概念）。因为 I/O 是在底层驱动程序上完成的。而底层驱动程序已经将相邻的页或相邻的字节合并成一个更大的单元。所以，如果你一开始就给它们一个更大的单元，它将以 512 字节为单位进行枚举。但驱动程序本身会重新组装成原始的 folio 或由 folio 指向的数据。

所以，这意味着实际上没有什么需要做的。它应该就能工作（just work）。就能工作。这并不真的是显而易见的方式，但是嗯，是的，它看起来不错。就目前而言，它应该能工作。所以，这本质上就是最终补丁所做的事情。

当然，我们需要让页缓存分配 folio，并确保一切真正在 folio 上工作，并且真正、真正地按 folio 的大小递增，而不是按页大小递增。然后还有，我们需要传递块限制（block limits），因为实际上是驱动程序告诉我们页缓存应该使用什么大小。所以我们需要一个接口来做这个。

这个工作得相当好，实际上太好了，因为我做的第一个补丁也用了 NFS。结果发现 NFS 为了，嗯，更高效，试图传输非常大的块，比如 128 兆，令人惊讶地工作了一段时间。所以，复制工作持续了，嗯，相当长一段时间，直到最后内存耗尽（out of memory），这巧妙地证明了，嗯，大块会导致更高的内存碎片化。嗯。如果还需要任何证明，这就是了。这就是了。

那么，就这些了吗？嗯。是的。嗯。嗯。嗯，差不多吧。因为很好我们让 Linux 内核能与支持大块大小的驱动器对话了，但确实还没有支持大块大小的驱动器，因为没人能和它们对话。所以我做的是更新了 BRD（块内存盘）驱动程序，让它实际显示或支持大块，这样你就有一些测试平台可以用来测试它了。这被证明是一个简单的测试平台。所以它实际上工作得相当好。你甚至可以，惊喜，惊喜，把它用作 NVMe 目标（NVMe target）的后端设备（backing device）。瞧，连 NVMe 也能用大块大小通信了。所以这相当酷。但是，当然，仍然需要一些测试，特别是块层中的拆分（splitting）和合并（merging）需要测试。而且，是的，在我的案例中它似乎工作了，但是，嗯，我能说什么呢？当然，嗯，还有什么？所以，QEMU 需要更新，因为对 QEMU 来说，支持大块大小应该是相当简单的。理论上，再次，你只需要修改驱动程序来显示或宣告大块大小。只是。我还没看过它，所以，像往常一样。理论上，一切都很简单。但是看看代码并了解 QEMU，它可能把代码分散得到处都是（split it all over the case, all over the code）。所以我不确定。而且，嗯，你需要用它们来测试驱动程序。你也可以用其他子系统进行测试。

而且，嗯，另一个是，我需要将我的补丁集与三星（Samsung）的那个统一起来。但很可能我下周会和 Luis 谈谈，希望我们能合并它们两个。当然，还有通常的代码审查（reviews）和善后（fallouts）等等。然后还有内存碎片化的问题。一旦我们迁移到大块大小，这将成为一个真正的问题。我想如果我们只是谈论 16K 的话，应该没问题。但问题仍然是，内存管理继续在页上运行。所以任何内部的分配很可能仍然会在页上进行。这意味着我们将在那里遇到增强的内存碎片化。

如果我们把整个系统切换到只按块大小分配，也许我们可以避免这个问题。但这假定你只有一个块大小。如果你有多个驱动器，每个都有不同的块大小，那它又行不通了。嗯。一个可能值得做的事情是更新 SLAB（或 SLUB/SLUB，统称内存分配器），使其在比页大小更高的阶（higher orders）的 folio 上运行。并且显然把每个使用 `alloc_page` 的地方都改成使用 SLAB/SLUB。这样就可以摆脱内部分配（internal allocation）。我希望通过这个，有可能减少内存碎片化，达到可以完全消除它的程度。因为你将总是按 folio 大小的增量分配内存。但是，你仍然没有解决这个问题。如果你有多个驱动器，每个都有不同的块大小，你该怎么做？对此我真的没有一个好主意。当然，如果有人有想法，我乐于接受其他建议。

当然，我需要更多的测试者，因为这真的需要测试。嗯，还有，如果你真的很无聊，还有块层，正如我所说，它以 512 字节为单位操作。所以，我们真的没有好的方法来改变它。谢天谢地，数据本身并不存储在 bio 里，而是存储在附加的结构里，在向量化的那个东西里，叫做 `bio_vec`，基本上就是那个结构。对于它，应该可以把 `struct page` 移到，嗯，`struct folio` 并直接使用它。或者甚至用一个联合体（union），允许通过 folio 或 page 来访问它。因为实际上开头的位是相同的。所以你可以直接，基本上你可以从 folio 强制转换（cast）到 page，反之亦然。所以，那应该是可能的。我还没看过。我还没尝试过。它应该是可能的。但再次，这适合那些真正下定决心去做的人，因为这绝对没有任何乐趣（no fun whatsoever）。那基本上是遍布各处（all over the place）。我刚刚检查了一下，`struct folio` 在块层被提到了 10 次。而 `bio_vec` 被提到了大约 4000 次。所以，嗯，可能会出什么问题呢？是的。

说到这里，我实际上讲完了。嘿，它在大屏幕上看起来比在我的笔记本电脑上好多了。好吧，很好。而且是的，我做了些事情。好的，很好。总之，非常感谢大家，我接受提问。

好的。我仍然接受提问。好了，所以，你们之后总能找到我。我会在这里或大厅和走廊里多待一会儿。非常感谢你们的耐心。
