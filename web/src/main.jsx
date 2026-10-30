import { useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './styles.css'

const fmt = (value) => new Intl.NumberFormat('en-US', { maximumFractionDigits: 3 }).format(value)

function App() {
  const [token0In, setToken0In] = useState(true)
  const [amount, setAmount] = useState('100')
  const [active, setActive] = useState('swap')
  const [connected, setConnected] = useState(false)
  const [notice, setNotice] = useState('SIMULATION READY — connect a wallet to trade')
  const input = Math.max(0, Number(amount) || 0)
  const output = useMemo(() => { const withFee = input * .997; return withFee * 84000 / (120000 + withFee) }, [input])
  const inputToken = token0In ? 'WETH' : 'RLY'
  const outputToken = token0In ? 'RLY' : 'WETH'
  const action = () => !connected ? setNotice('WALLET HANDSHAKE REQUIRED — demo interface only') : setNotice(`TX PREPARED — swap ${fmt(input)} ${inputToken} for ≥ ${fmt(output * .995)} ${outputToken}`)
  const code = 'function swapExactIn(\\n  bool token0In, uint256 amountIn,\\n  uint256 minAmountOut, address to\\n) external lock returns (uint256 out)\\n\\namountInWithFee = amountIn * 997;\\nout = amountInWithFee * reserveOut /\\n  (reserveIn * 1000 + amountInWithFee);'
  return <main>
    <nav><a className="brand" href="#top"><span>◈</span> RELAY<span>SWAP</span></a><div className="navlinks"><a href="#protocol">Protocol</a><a href="#terminal">Terminal</a><a href="https://github.com/tejaswikharade" target="_blank">GitHub ↗</a></div><button className="wallet" onClick={() => { setConnected(!connected); setNotice(connected ? 'WALLET DISCONNECTED' : 'WALLET CONNECTED — 0x7F…42A1') }}>{connected ? '0x7F…42A1' : 'Connect wallet'}</button></nav>
    <section className="hero" id="top"><div className="hero-copy"><p className="eyebrow">// PERMISSIONLESS LIQUIDITY INFRASTRUCTURE</p><h1>Liquidity<br/><i>in motion.</i></h1><p className="lede">RelaySwap is a compact constant-product AMM: clear math, transparent fee flows, and composable on-chain liquidity.</p><div className="hero-actions"><a className="primary" href="#terminal">Launch terminal <b>→</b></a><a className="text-link" href="#protocol">Read the architecture</a></div><div className="metrics"><div><strong>$2.1M</strong><span>demo TVL</span></div><div><strong>0.30%</strong><span>LP fee</span></div><div><strong>1 block</strong><span>finality target</span></div></div></div><div className="orbital" aria-label="constant product visual"><div className="ring ring-a"></div><div className="ring ring-b"></div><div className="core">x · y<br/><em>= k</em></div><span className="node one">WETH</span><span className="node two">RLY</span></div></section>
    <section className="terminal-grid" id="terminal"><div className="trade-panel"><div className="panel-top"><span className="dot"></span><span>RELAY / EXECUTION TERMINAL</span><span className="live">● LIVE DEMO</span></div><div className="tabs"><button className={active === 'swap' ? 'selected' : ''} onClick={() => setActive('swap')}>Swap</button><button className={active === 'liquidity' ? 'selected' : ''} onClick={() => setActive('liquidity')}>Liquidity</button></div><div className="asset-box"><label>YOU PAY</label><div><input aria-label="amount in" value={amount} inputMode="decimal" onChange={e => setAmount(e.target.value)} /><button onClick={() => setAmount('1200')}>MAX</button><span className="token">{inputToken}</span></div><small>Balance: 1,200.00 {inputToken}</small></div><button className="flip" onClick={() => setToken0In(!token0In)}>↓</button><div className="asset-box dark"><label>YOU RECEIVE</label><div><strong>{fmt(output)}</strong><span className="token accent">{outputToken}</span></div><small>Rate includes 0.30% LP fee</small></div><div className="trade-data"><span>Price impact <b>0.08%</b></span><span>Min. received <b>{fmt(output * .995)} {outputToken}</b></span><span>Route <b>Direct pool</b></span></div><button className="execute" onClick={action}>{connected ? `Swap ${inputToken} → ${outputToken}` : 'Connect to trade'} <b>↗</b></button><p className="notice">&gt; {notice}</p></div><aside className="code-card"><div className="code-head"><span>PAIR.SOL</span><span>0.8.24</span></div><pre><code>{code}</code></pre><div className="code-foot">✓ REENTRANCY LOCK &nbsp; ✓ SLIPPAGE GUARD &nbsp; ✓ EVENTS</div></aside></section>
    <section className="principles" id="protocol"><p className="eyebrow">// BUILT TO BE READ</p><h2>Small surface.<br/>Serious primitives.</h2><div className="feature-row"><article><span>01</span><h3>Constant product</h3><p>The x · y = k curve sets price directly from pool reserves, with no order book required.</p></article><article><span>02</span><h3>LP ownership</h3><p>Pool shares are ERC-20 compatible claims on reserves and accrued trading fees.</p></article><article><span>03</span><h3>Guarded execution</h3><p>Minimum outputs, checked transfers, reserve bounds, and a reentrancy lock sit at every critical edge.</p></article></div></section>
    <footer><span>RELAYSWAP / EDUCATIONAL BUILD</span><span>NO AUDIT · USE AT YOUR OWN RISK</span><a href="https://github.com/tejaswikharade" target="_blank">SOURCE ↗</a></footer>
  </main>
}
createRoot(document.getElementById('root')).render(<App />)
