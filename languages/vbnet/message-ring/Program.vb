' message-ring: cooperative concurrency / message-passing overhead axis.
' 32 async workers in a ring on a SINGLE OS thread, driven by main for N laps.
' Each hop: worker receives token v, applies the LCG transform, forwards to next.
' Primitive: Async/Await on a SingleThreadContext (message-loop SynchronizationContext), with
' TaskCompletionSource(Of Long) rendezvous. The ThreadPool is never used.
'
' Token transform (32-bit unsigned wrap, carried in a Long in [0, 2^32)):
'   v = (v * 1103515245 + (id + 1)) And &HFFFFFFFF
' The product is at most 4.74e18, below Long.MaxValue, so no overflow check can fire.
'
' Output:
'   line 1: v Mod 1000000007   (checksum)
'   line 2: n * RING_WIDTH     (secondary: total hops)
Imports System
Imports System.Collections.Concurrent
Imports System.Collections.Generic
Imports System.Threading
Imports System.Threading.Tasks

' ---- Single-thread SynchronizationContext + TaskScheduler --------------------
' All continuations and tasks scheduled here execute serially on the one thread that calls
' RunLoop(). No ThreadPool thread ever picks up work.
NotInheritable Class SingleThreadContext
    Inherits SynchronizationContext

    Private ReadOnly _queue As New BlockingCollection(Of (cb As SendOrPostCallback, state As Object))()

    ' TaskScheduler that queues tasks onto this context.
    Private ReadOnly _scheduler As TaskScheduler
    Public ReadOnly Property Scheduler As TaskScheduler
        Get
            Return _scheduler
        End Get
    End Property

    Public Sub New()
        _scheduler = New SyncContextTaskScheduler(Me)
    End Sub

    Public Overrides Sub Post(d As SendOrPostCallback, state As Object)
        _queue.Add((d, state))
    End Sub

    Public Overrides Sub Send(d As SendOrPostCallback, state As Object)
        Throw New NotSupportedException("Synchronous Send not supported")
    End Sub

    ' Run the message loop on the CURRENT thread until the given task completes.
    Public Sub RunLoop(task As Task)
        ' When the top-level task finishes, stop the queue.
        task.ContinueWith(Sub(t As Task) _queue.CompleteAdding(), TaskScheduler.Default)
        ' Drain the queue on THIS thread.
        For Each item In _queue.GetConsumingEnumerable()
            item.cb(item.state)
        Next
        task.GetAwaiter().GetResult() ' propagate any exception
    End Sub

    ' Inline TaskScheduler that posts work to the enclosing SynchronizationContext.
    Private NotInheritable Class SyncContextTaskScheduler
        Inherits TaskScheduler

        Private ReadOnly _ctx As SingleThreadContext

        Public Sub New(ctx As SingleThreadContext)
            _ctx = ctx
        End Sub

        Protected Overrides Sub QueueTask(task As Task)
            _ctx.Post(Sub(o As Object) TryExecuteTask(task), Nothing)
        End Sub

        Protected Overrides Function TryExecuteTaskInline(task As Task, taskWasPreviouslyQueued As Boolean) As Boolean
            Return False ' always queue; inline could break ordering
        End Function

        Protected Overrides Function GetScheduledTasks() As IEnumerable(Of Task)
            Return Nothing
        End Function
    End Class
End Class

' ---- One-slot async rendezvous -----------------------------------------------
' Sender calls SendAsync(v): posts value, then awaits acknowledgement.
' Receiver calls ReceiveAsync(): awaits value, acknowledges, returns value.
' Both sides cooperatively yield until the handshake completes; this IS the
' async/await context switch being measured.
NotInheritable Class Rendezvous
    ' Sender posts value here; receiver awaits this.
    Private _slot As New TaskCompletionSource(Of Long)(TaskCreationOptions.RunContinuationsAsynchronously)
    ' Receiver posts ack here; sender awaits this.
    Private _ack As New TaskCompletionSource(Of Boolean)(TaskCreationOptions.RunContinuationsAsynchronously)

    Public Async Function SendAsync(v As Long) As Task
        _slot.SetResult(v)
        Await _ack.Task
    End Function

    Public Async Function ReceiveAsync() As Task(Of Long)
        Dim v As Long = Await _slot.Task
        ' Prepare the TCSes for the NEXT lap before completing the ack,
        ' so the sender can immediately post again on the next lap.
        _slot = New TaskCompletionSource(Of Long)(TaskCreationOptions.RunContinuationsAsynchronously)
        Dim oldAck = _ack
        _ack = New TaskCompletionSource(Of Boolean)(TaskCreationOptions.RunContinuationsAsynchronously)
        oldAck.SetResult(True)
        Return v
    End Function
End Class

Module MessageRing
    Const RING_WIDTH As Integer = 32
    Const SEED As Long = 12345L
    Const MODP As Long = 1000000007L
    Const LCG_MUL As Long = 1103515245L
    Const MASK As Long = &HFFFFFFFFL

    ' Entry point for the ring logic -- runs entirely on the single-thread context.
    Async Function RunRing(n As Integer, scheduler As TaskScheduler) As Task
        ' channels(i) is the channel INTO worker i (and (32) is from worker 31 back to main).
        Dim channels As Rendezvous() = New Rendezvous(RING_WIDTH) {}
        For i As Integer = 0 To RING_WIDTH
            channels(i) = New Rendezvous()
        Next

        ' Create all 32 worker tasks on the single-thread scheduler.
        Dim workers As Task() = New Task(RING_WIDTH - 1) {}
        For id As Integer = 0 To RING_WIDTH - 1
            Dim wid As Integer = id
            Dim addend As Long = wid + 1
            Dim inbox As Rendezvous = channels(wid)
            Dim outbox As Rendezvous = channels(wid + 1)

            workers(wid) = Task.Factory.StartNew(
                Async Function() As Task
                    For lap As Integer = 0 To n - 1
                        Dim v As Long = Await inbox.ReceiveAsync()
                        v = (v * LCG_MUL + addend) And MASK ' 32-bit unsigned wrap
                        Await outbox.SendAsync(v)
                    Next
                End Function,
                CancellationToken.None,
                TaskCreationOptions.DenyChildAttach,
                scheduler).Unwrap()
        Next

        ' Main lap loop on the same single-thread context.
        Dim token As Long = SEED
        Dim mainToRing As Rendezvous = channels(0)
        Dim ringToMain As Rendezvous = channels(RING_WIDTH)
        For lap As Integer = 0 To n - 1
            Await mainToRing.SendAsync(token)
            token = Await ringToMain.ReceiveAsync()
        Next

        Await Task.WhenAll(workers)

        Console.WriteLine(token Mod MODP)
        Console.WriteLine(n * RING_WIDTH)
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 2000)

        Dim ctx As New SingleThreadContext()
        SynchronizationContext.SetSynchronizationContext(ctx)

        ' Kick off the ring task on the single-thread scheduler, then run the loop.
        Dim top As Task = Task.Factory.StartNew(
            Function() RunRing(n, ctx.Scheduler),
            CancellationToken.None,
            TaskCreationOptions.DenyChildAttach,
            ctx.Scheduler).Unwrap()

        ctx.RunLoop(top)
    End Sub
End Module
