import UIKit
import WebKit
import Capacitor

// Main view controller per l'app Capacitor.
// Inietta CSS/JS SOLO dentro la webview dell'app (nessuna modifica alla webapp di produzione).
class MainViewController: CAPBridgeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        injectAppOnlyEnhancements()
    }

    private func injectAppOnlyEnhancements() {
        guard let webView = self.bridge?.webView else { return }
        let ucc = webView.configuration.userContentController

        // Forza/aggiunge un marker nell'User-Agent per distinguere l'app iOS
        webView.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                if !ua.contains("KimStationApp") {
                    webView.customUserAgent = ua + " KimStationApp"
                }
            } else {
                webView.customUserAgent = "KimStationApp"
            }
        }

        // 1) CSS responsive: sticky prima colonna, scroll orizzontale, card sotto 576px
        let css = """
        /* Wrapper scrollabile */
        .table-responsive { overflow-x:auto; -webkit-overflow-scrolling:touch; }

        /* Sticky prima colonna (solo se tabella ha >1 colonna) */
        @media (max-width: 768px) {
          table.app-mobile { border-collapse: separate; border-spacing: 0; }
          table.app-mobile td:first-child, table.app-mobile th:first-child { position: sticky; left: 0; z-index: 2; background: #fff; }
        }

        /* Nascondi colonne a priorità bassa su tablet/mobile */
        @media (max-width: 768px) {
          table.app-mobile td._hide768, table.app-mobile th._hide768 { display: none !important; }
        }

        /* Layout a card su schermi molto piccoli */
        @media (max-width: 576px) {
          table.app-mobile thead { display: none !important; }
          table.app-mobile tbody tr { display: block; border: 1px solid #e5e7eb; border-radius: 10px; padding: 8px 10px; margin-bottom: 10px; background: #fff; }
          table.app-mobile tbody td { display: block; border: 0; padding: 6px 8px; position: relative; }
          table.app-mobile tbody td::before { content: attr(data-label); font-weight: 600; color: #4b5563; margin-right: 8px; }
          table.app-mobile td._hide768 { display: none; }
          .app-mobile-details { display: none; padding: 8px 10px; background:#f8fafc; border-radius:8px; margin-top:6px; }
          .app-mobile-row-actions { display:flex; justify-content:flex-end; margin-top:6px; }
          .app-mobile-toggle { background:#e5edff; color:#1e3a8a; border:none; border-radius:8px; padding:6px 10px; font-weight:600; }
        }
        """
        let cssJS = """
        (function(){
          try {
            var style = document.createElement('style');
            style.id = 'kim-app-mobile-css';
            style.textContent = `\n""" + css.replacingOccurrences(of: "`", with: "\\`") + "\n`" + ";" + "\n            if(!document.getElementById('kim-app-mobile-css')) document.head.appendChild(style);\n          } catch(e) { console.log('[KimApp] CSS inject error', e); }
        })();
        """
        let cssScript = WKUserScript(source: cssJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(cssScript)

        // 2) JS: applica regole a #tabella-attivazioni e #tabella-ordini
        let js = """
        (function(){
          function textNormalize(s){ return (s||'').trim().toLowerCase(); }
          function findHeaderIndex(table, headerText){
            var thead = table.querySelector('thead');
            if(!thead) return -1;
            var ths = Array.from(thead.querySelectorAll('th'));
            var target = textNormalize(headerText);
            for (var i=0;i<ths.length;i++){
              if(textNormalize(ths[i].textContent) === target) return i;
            }
            return -1;
          }
          function labelize(table){
            var ths = Array.from((table.querySelector('thead')||{}).querySelectorAll ? table.querySelector('thead').querySelectorAll('th') : []);
            Array.from(table.querySelectorAll('tbody tr')).forEach(function(tr){
              Array.from(tr.children).forEach(function(td, idx){
                var label = ths[idx] ? ths[idx].textContent.trim() : '';
                td.setAttribute('data-label', label);
              });
            });
          }
          function wrapResponsive(table){
            if (table.parentElement && !table.parentElement.classList.contains('table-responsive')){
              var wrapper = document.createElement('div');
              wrapper.className = 'table-responsive';
              table.parentElement.insertBefore(wrapper, table);
              wrapper.appendChild(table);
            }
            table.classList.add('app-mobile');
          }
          function hideColumnsByNames(table, names){
            var indexes = names.map(function(n){return findHeaderIndex(table, n);}).filter(function(i){return i>=0;});
            if(indexes.length===0) return;
            var theadRow = table.querySelector('thead tr');
            if (theadRow){ indexes.forEach(function(i){ var th = theadRow.children[i]; if(th) th.classList.add('_hide768'); }); }
            Array.from(table.querySelectorAll('tbody tr')).forEach(function(tr){
              indexes.forEach(function(i){ var td = tr.children[i]; if(td) td.classList.add('_hide768'); });
            });
          }
          function addDetailsToggle(table, names){
            var indexes = names.map(function(n){return findHeaderIndex(table, n);}).filter(function(i){return i>=0;});
            if(indexes.length===0) return;
            Array.from(table.querySelectorAll('tbody tr')).forEach(function(tr){
              if (tr._detailsBound) return; tr._detailsBound = true;
              var btnRow = document.createElement('div');
              btnRow.className = 'app-mobile-row-actions';
              var btn = document.createElement('button');
              btn.className = 'app-mobile-toggle';
              btn.type = 'button';
              btn.textContent = 'Dettagli';
              var details = document.createElement('div');
              details.className = 'app-mobile-details';
              btn.addEventListener('click', function(){
                if(details.style.display==='block'){ details.style.display='none'; return; }
                // ricostruisci contenuti
                details.innerHTML='';
                indexes.forEach(function(i){
                  var td = tr.children[i];
                  if(!td) return;
                  var label = (table.querySelectorAll('thead th')[i]||{}).textContent || '';
                  var row = document.createElement('div');
                  row.style.display='flex'; row.style.justifyContent='space-between'; row.style.gap='8px';
                  var l = document.createElement('strong'); l.textContent = (label||'').trim()+':';
                  var v = document.createElement('span'); v.innerHTML = td.innerHTML;
                  row.appendChild(l); row.appendChild(v);
                  details.appendChild(row);
                });
                details.style.display='block';
              });
              var tdContainer = document.createElement('td');
              tdContainer.colSpan = tr.children.length;
              tdContainer.appendChild(details);
              tdContainer.appendChild(btnRow);
              btnRow.appendChild(btn);
              var detailsTr = document.createElement('tr');
              detailsTr.className = 'app-mobile-extra';
              detailsTr.appendChild(tdContainer);
              tr.parentNode.insertBefore(detailsTr, tr.nextSibling);
            });
          }
          function enhance(selector, hideNames){
            var table = document.querySelector(selector);
            if(!table) return;
            // Esegui solo se esiste un tbody e ha almeno una riga (evita interferenze con rendering asincrono)
            var tb = table.querySelector('tbody');
            if(!tb) return;
            if(tb && tb.querySelectorAll('tr').length === 0) return;
            wrapResponsive(table);
            labelize(table);
            hideColumnsByNames(table, hideNames);
            addDetailsToggle(table, hideNames);
          }
          function run(){
            enhance('#tabella-attivazioni', ['Tipo','Segmento']);
            enhance('#tabella-ordini', ['Prodotto','Stato']);
            // Estende agli ID specifici per dashboard agente
            enhance('#tabella-attivazioni-agente', ['Tipo','Segmento']);
            enhance('#tabella-ordini-agente', ['Prodotto','Stato']);
            // Estende agli ID specifici per dashboard dealer
            enhance('#tabella-attivazioni-dealer', ['Tipo','Segmento']);
            enhance('#tabella-ordini-dealer', ['Prodotto','Stato']);
          }
          // Esegui quando pronto + osserva mutazioni (caricamenti asincroni)
          var readyInterval = setInterval(function(){
            if(document.readyState === 'complete' || document.readyState === 'interactive'){
              try{ run(); }catch(e){ console.log('[KimApp] enhance error', e); }
              clearInterval(readyInterval);
            }
          }, 200);
          var obs = new MutationObserver(function(m){ try{ run(); }catch(e){} });
          obs.observe(document.documentElement, { subtree:true, childList:true });
        })();
        """
        let jsScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(jsScript)
    }
}
