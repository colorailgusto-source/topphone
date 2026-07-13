var stripe;

function createPaymentOverlay(publishableKey, clientSecret, amountText) {
  return new Promise(function(resolve) {
    stripe = Stripe(publishableKey);
    var elements = stripe.elements();

    var overlay = document.createElement('div');
    overlay.id = 'stripe-overlay';
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.6);z-index:99999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px);';

    var dialog = document.createElement('div');
    dialog.style.cssText = 'background:white;border-radius:20px;padding:32px 28px;width:90%;max-width:400px;box-shadow:0 25px 60px rgba(0,0,0,0.3);';

    dialog.innerHTML = '<div style="text-align:center;margin-bottom:24px;">'
      + '<div style="width:56px;height:56px;background:linear-gradient(135deg,#01579B,#0288D1);border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 12px;">'
      + '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>'
      + '</div>'
      + '<div style="font-size:22px;font-weight:700;color:#01579B;font-family:Poppins,sans-serif;">Pagamento Sicuro</div>'
      + '<div style="font-size:17px;color:#333;margin-top:6px;font-weight:600;">' + amountText + '</div>'
      + '</div>'
      + '<div style="font-size:13px;color:#666;margin-bottom:8px;font-family:Poppins,sans-serif;">Dati carta</div>'
      + '<div id="stripe-card-element" style="border:2px solid #e0e0e0;border-radius:12px;padding:16px;margin-bottom:8px;transition:border-color 0.2s;"></div>'
      + '<div id="stripe-card-errors" style="color:#e53935;font-size:12px;margin-bottom:16px;min-height:18px;font-family:Poppins,sans-serif;"></div>'
      + '<button id="stripe-pay-btn" style="width:100%;padding:16px;background:linear-gradient(135deg,#01579B,#0288D1);color:white;border:none;border-radius:12px;font-size:16px;font-weight:600;cursor:pointer;font-family:Poppins,sans-serif;">Paga ora</button>'
      + '<button id="stripe-cancel-btn" style="width:100%;padding:12px;background:transparent;color:#888;border:none;border-radius:8px;font-size:14px;cursor:pointer;margin-top:10px;font-family:Poppins,sans-serif;">Annulla</button>'
      + '<div style="text-align:center;margin-top:16px;display:flex;align-items:center;justify-content:center;gap:6px;">'
      + '<svg width="14" height="14" viewBox="0 0 24 24" fill="#4CAF50"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"/></svg>'
      + '<span style="font-size:11px;color:#888;">Protetto da Stripe</span>'
      + '</div>';

    overlay.appendChild(dialog);
    document.body.appendChild(overlay);

    var cardElement = elements.create('card', {
      style: {
        base: {
          fontSize: '16px',
          color: '#333',
          fontFamily: 'Poppins, sans-serif',
          '::placeholder': { color: '#aab7c4' }
        },
        invalid: { color: '#e53935' }
      },
      hidePostalCode: true
    });
    cardElement.mount('#stripe-card-element');

    cardElement.on('change', function(event) {
      var errDiv = document.getElementById('stripe-card-errors');
      errDiv.textContent = event.error ? event.error.message : '';
      var el = document.getElementById('stripe-card-element');
      el.style.borderColor = event.error ? '#e53935' : (event.complete ? '#4CAF50' : '#e0e0e0');
    });

    document.getElementById('stripe-pay-btn').addEventListener('click', async function() {
      var btn = document.getElementById('stripe-pay-btn');
      btn.disabled = true;
      btn.style.opacity = '0.7';
      btn.textContent = 'Elaborazione...';

      var result = await stripe.confirmCardPayment(clientSecret, {
        payment_method: { card: cardElement }
      });

      if (result.error) {
        document.getElementById('stripe-card-errors').textContent = result.error.message;
        btn.disabled = false;
        btn.style.opacity = '1';
        btn.textContent = 'Paga ora';
      } else {
        overlay.remove();
        resolve('success');
      }
    });

    document.getElementById('stripe-cancel-btn').addEventListener('click', function() {
      overlay.remove();
      resolve('cancelled');
    });

    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) {
        overlay.remove();
        resolve('cancelled');
      }
    });
  });
}
